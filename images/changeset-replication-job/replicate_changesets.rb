#!/usr/bin/env ruby

# Copied from the OpenStreetMap chef repository:
# https://github.com/openstreetmap/chef/blob/c97d0846c6566c022502f8a6a07d3fcea1ca3fe8/cookbooks/planet/templates/default/replicate-changesets.erb
# Local changes: the shebang, and the run is skipped when there are no changesets (see save!).
# To update, copy the new version of that file here and apply those two changes again.

require "rubygems"
require "bigdecimal"
require "pg"
require "yaml"
require "time"
require "fileutils"
require "xml/libxml"
require "zlib"
require "set"

# after this many changes, a changeset will be closed
CHANGES_LIMIT = 50000

# this is the scale factor for lat/lon values stored as integers in the database
GEO_SCALE = 10000000

##
# replace characters which cannot be represented in XML 1.0.
def xml_sanitize(str)
  str.gsub(/[\x00-\x08\x0b\x0c\x0e-\x1f]/, "?")
end

##
# changeset class keeps some information about changesets downloaded from the
# database - enough to let us know which changesets are closed/open & recently
# closed.
class Changeset
  attr_reader :id, :created_at, :closed_at, :num_changes

  def initialize(row)
    @id = row["id"].to_i
    @created_at = Time.parse(row["created_at"])
    @closed_at = Time.parse(row["closed_at"])
    @num_changes = row["num_changes"].to_i
  end

  def closed?(t)
    (@closed_at < t) || (@num_changes >= CHANGES_LIMIT)
  end

  def open?(t)
    !closed?(t)
  end

  def activity_between?(t1, t2)
    ((@closed_at >= t1) && (@closed_at < t2)) || ((@created_at >= t1) && (@created_at < t2))
  end
end

##
# builds an XML representation of a changeset from the database
class ChangesetBuilder
  def initialize(now, conn)
    @now = now
    @conn = conn
  end

  def changeset_xml(cs)
    xml = XML::Node.new("changeset")
    xml["id"] = cs.id.to_s
    xml["created_at"] = cs.created_at.getutc.xmlschema
    xml["closed_at"] = cs.closed_at.getutc.xmlschema if cs.closed?(@now)
    xml["open"] = cs.open?(@now).to_s
    xml["num_changes"] = cs.num_changes.to_s

    res = @conn.exec("select u.id, u.display_name, c.min_lat, c.max_lat, c.min_lon, c.max_lon from users u join changesets c on u.id=c.user_id where c.id=#{cs.id}")
    xml["user"] = xml_sanitize(res[0]["display_name"])
    xml["uid"] = res[0]["id"]

    unless res[0]["min_lat"].nil? ||
           res[0]["max_lat"].nil? ||
           res[0]["min_lon"].nil? ||
           res[0]["max_lon"].nil?
      xml["min_lat"] = (res[0]["min_lat"].to_f / GEO_SCALE).to_s
      xml["max_lat"] = (res[0]["max_lat"].to_f / GEO_SCALE).to_s
      xml["min_lon"] = (res[0]["min_lon"].to_f / GEO_SCALE).to_s
      xml["max_lon"] = (res[0]["max_lon"].to_f / GEO_SCALE).to_s
    end

    add_tags(xml, cs)
    add_comments(xml, cs)

    xml
  end

  def add_tags(xml, cs)
    res = @conn.exec("select k, v from changeset_tags where changeset_id=#{cs.id}")
    res.each do |row|
      tag = XML::Node.new("tag")
      tag["k"] = xml_sanitize(row["k"])
      tag["v"] = xml_sanitize(row["v"])
      xml << tag
    end
  end

  def add_comments(xml, cs)
    # grab the visible changeset comments as well
    res = @conn.exec("select cc.id, cc.author_id, u.display_name as author, cc.body, (cc.created_at at time zone 'utc') as created_at from changeset_comments cc join users u on cc.author_id=u.id where cc.changeset_id=#{cs.id} and cc.visible order by cc.created_at asc")
    xml["comments_count"] = res.num_tuples.to_s

    # early return if there aren't any comments
    return unless res.num_tuples.positive?

    discussion = XML::Node.new("discussion")
    res.each do |row|
      comment = XML::Node.new("comment")
      comment["id"] = row["id"]
      comment["uid"] = row["author_id"]
      comment["user"] = xml_sanitize(row["author"])
      comment["date"] = Time.parse(row["created_at"]).getutc.xmlschema
      text = XML::Node.new("text")
      text.content = xml_sanitize(row["body"])
      comment << text
      discussion << comment
    end
    xml << discussion
  end
end

##
# sync a file to guarantee it's on disk
def fsync(f)
  File.open(f, &:fsync)
end

##
# sync a directory to guarantee it's on disk. have to recurse to the root
# to guarantee sync for newly created directories.
def fdirsync(d)
  while d != "/" && d != "."
    fsync(d)
    d = File.dirname(d)
  end
end

##
# state and connections associated with getting changeset data
# replicated to a file.
class Replicator
  def initialize(config)
    @config = YAML.safe_load(File.read(config))
    @state = YAML.safe_load(File.read(@config["state_file"]), :permitted_classes => [Time], :fallback => {})
    @conn = PG::Connection.connect(@config["db"])
    # get current time from the database rather than the current system
    @now = @conn.exec("select now() as now").map { |row| Time.parse(row["now"]) }[0]
  end

  def open_changesets
    last_run = @state["last_run"]
    last_run = (@now - 60) if last_run.nil?
    # pretty much all operations on a changeset will modify its closed_at
    # time (see rails_port's changeset model). so it is probably enough
    # for us to look at anything that was closed recently, and filter from
    # there.
    changesets = @conn
                 .exec("select id, (created_at at time zone 'utc') as created_at, (closed_at at time zone 'utc') as closed_at, num_changes from changesets where (closed_at at time zone 'utc') > ((now() at time zone 'utc') - '1 hour'::interval)")
                 .map { |row| Changeset.new(row) }
                 .select { |cs| cs.activity_between?(last_run, @now) }

    # set for faster presence lookups by ID
    cs_ids = Set.new(changesets.map(&:id))

    # but also add any changesets which have new comments
    new_ids = @conn
              .exec("select distinct changeset_id from changeset_comments where (created_at at time zone 'utc') >= '#{last_run}' and (created_at at time zone 'utc') < '#{@now}' and visible")
              .map { |row| row["changeset_id"].to_i }
              .reject { |c_id| cs_ids.include?(c_id) }

    new_ids.each do |id|
      @conn
        .exec("select id, (created_at at time zone 'utc') as created_at, (closed_at at time zone 'utc') as closed_at, num_changes from changesets where id=#{id}")
        .map { |row| Changeset.new(row) }
        .each { |cs| changesets << cs }
    end

    changesets.sort_by(&:id)
  end

  # creates an XML file containing the changeset information from the
  # list of changesets output by open_changesets.
  def changeset_dump(changesets)
    doc = XML::Document.new
    doc.root = XML::Node.new("osm")
    { "version" => "0.6",
      "generator" => "replicate_changesets.rb",
      "copyright" => "OpenStreetMap and contributors",
      "attribution" => "https://www.openstreetmap.org/copyright",
      "license" => "https://opendatacommons.org/licenses/odbl/1-0/" }
      .each { |k, v| doc.root[k] = v }

    builder = ChangesetBuilder.new(@now, @conn)
    changesets.each do |cs|
      doc.root << builder.changeset_xml(cs)
    end

    doc.to_s
  end

  def sequence
    @state.key?("sequence") ? @state["sequence"] + 1 : 0
  end

  def data_stem
    @config["data_dir"] + format("/%03d/%03d/%03d", sequence / 1000000, (sequence / 1000) % 1000, (sequence % 1000))
  end

  def s3_stem
    @config["s3_dir"] + format("/%03d/%03d/%03d", sequence / 1000000, (sequence / 1000) % 1000, (sequence % 1000))
  end

  def write_tmp_files!(changesets)
    data_file = data_stem + ".osm.gz"
    tmp_state = @config["state_file"] + ".tmp"
    tmp_data = data_file + ".tmp"

    FileUtils.mkdir_p(File.dirname(data_file))
    Zlib::GzipWriter.open(tmp_data) do |fh|
      fh.write(changeset_dump(changesets))
    end
    File.write(tmp_state, YAML.dump(@state))

    # fsync the files in their old locations.
    fsync(tmp_data)
    fsync(tmp_state)

    # sync the directory as well, to ensure that the file is reachable
    # from the dirent and has been updated to account for any allocations.
    fdirsync(File.dirname(tmp_data))
    fdirsync(File.dirname(tmp_state))

    # sanity check: the files we're moving into place
    # should be non-empty.
    raise "Temporary gzip file should exist, but doesn't." unless File.exist?(tmp_data)
    raise "Temporary state file should exist, but doesn't." unless File.exist?(tmp_state)
    raise "Temporary gzip file should be non-empty, but isn't." if File.zero?(tmp_data)
    raise "Temporary state file should be non-empty, but isn't." if File.zero?(tmp_state)
  end

  def move_tmp_files_into_place!
    data_file = data_stem + ".osm.gz"
    data_state_file = data_stem + ".state.txt"
    tmp_state = @config["state_file"] + ".tmp"
    tmp_data = data_file + ".tmp"

    FileUtils.mv(tmp_data, data_file)
    FileUtils.cp(tmp_state, @config["state_file"])
    FileUtils.mv(tmp_state, data_state_file)

    # fsync the files in their new locations, in case the inodes have
    # changed in the move / copy.
    fsync(data_file)
    fsync(@config["state_file"])
    fsync(data_state_file)

    # sync the directory as well, to ensure that the file is reachable
    # from the dirent and has been updated to account for any allocations.
    fdirsync(File.dirname(data_file))
    fdirsync(File.dirname(@config["state_file"]))

    if @config["s3_dir"]
      s3_file = s3_stem + ".osm.gz"
      s3_state_file = s3_stem + ".state.txt"
      s3_state_config_file = @config["s3_dir"] + "/state.yaml"

      system("/opt/awscli/v2/current/bin/aws", "--profile=osm-pds-upload", "s3", "cp", "--storage-class=INTELLIGENT_TIERING", "--no-progress", data_file, s3_file)
      system("/opt/awscli/v2/current/bin/aws", "--profile=osm-pds-upload", "s3", "cp", "--storage-class=INTELLIGENT_TIERING", "--no-progress", data_state_file, s3_state_file)
      system("/opt/awscli/v2/current/bin/aws", "--profile=osm-pds-upload", "s3", "cp", "--storage-class=INTELLIGENT_TIERING", "--no-progress", @config["state_file"], s3_state_config_file)
    end
  end

  # saves new state (including the changeset dump xml)
  def save!
    File.open(@config["lock_file"], File::RDWR | File::CREAT, 0o600) do |fl|
      # take the lock in non-blocking mode. if this process doesn't get the lock
      # then another will be run from cron shortly. this prevents a whole bunch
      # of processes queueing on the lock and causing weirdness if/when they
      # get woken up in a random order.
      got_lock = fl.flock(File::LOCK_EX | File::LOCK_NB)
      break unless got_lock

      # try and write the files to tmp locations and then
      # move them into place later, to avoid in-progress
      # clashes, or people seeing incomplete files.
      begin
        changesets = open_changesets

        # Local change: write nothing when there are no changesets to publish.
        # The sequence and last_run stay the same, so the next run covers this time too.
        if changesets.empty?
          fl.flock(File::LOCK_UN)
          break
        end

        @state["sequence"] = sequence
        @state["last_run"] = @now

        write_tmp_files!(changesets)

        move_tmp_files_into_place!

        fl.flock(File::LOCK_UN)
      rescue StandardError
        warn "Error! Couldn't update state."
        fl.flock(File::LOCK_UN)
        raise
      end
    end
  end
end

begin
  rep = Replicator.new(ARGV[0])
  rep.save!
rescue StandardError => e
  warn "ERROR: #{e.message}"
  e.backtrace.each do |frame|
    warn "ERROR: #{frame}"
  end
  exit 1
end
