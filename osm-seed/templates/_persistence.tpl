{{/*
Persistent storage helpers. Each component template keeps its own PersistentVolume and
PersistentVolumeClaim objects (name, labels) and uses these helpers for the spec.

  storageProvider aws
    AWS_ElasticBlockStore_volumeID set  -> static PV on that EBS volume, PVC bound to it
    volumeID empty                      -> dynamic PVC (storageClassName, size)
  storageProvider k3s
    staticHostPath true                 -> static hostPath PV (localVolumeHostPath), PVC bound to it
    staticHostPath false                -> dynamic PVC on local-path (localVolumeSize)

All helpers take (dict "root" . "values" .Values.<component> "name" "<pv/pvc name>").
*/}}

{{/* "true" when the component needs a static PersistentVolume, empty otherwise. */}}
{{- define "osm-seed.pv.static" -}}
{{- $p := .values.persistenceDisk -}}
{{- $cp := include "osm-seed.storageProvider" .root -}}
{{- if or (and (eq $cp "k3s") $p.staticHostPath) (and (eq $cp "aws") $p.AWS_ElasticBlockStore_volumeID) }}true{{- end -}}
{{- end -}}

{{/* spec of the static PersistentVolume. */}}
{{- define "osm-seed.pv.spec" -}}
{{- $p := .values.persistenceDisk -}}
storageClassName: ""
accessModes:
  - ReadWriteOnce
{{- if eq (include "osm-seed.storageProvider" .root) "aws" }}
capacity:
  storage: {{ $p.AWS_ElasticBlockStore_size }}
awsElasticBlockStore:
  volumeID: {{ $p.AWS_ElasticBlockStore_volumeID }}
  fsType: ext4
{{- else }}
persistentVolumeReclaimPolicy: Retain
capacity:
  storage: {{ $p.localVolumeSize }}
hostPath:
  path: {{ $p.localVolumeHostPath | quote }}
  type: DirectoryOrCreate
{{- end }}
{{- end -}}

{{/* spec of the PersistentVolumeClaim, bound to the static PV when there is one. */}}
{{- define "osm-seed.pvc.spec" -}}
{{- $p := .values.persistenceDisk -}}
{{- $k3s := eq (include "osm-seed.storageProvider" .root) "k3s" -}}
{{- $static := include "osm-seed.pv.static" . -}}
{{- if $static }}
storageClassName: ""
volumeName: {{ .name }}
{{- else if $k3s }}
storageClassName: local-path
{{- else if $p.storageClassName }}
storageClassName: {{ $p.storageClassName | quote }}
{{- end }}
accessModes:
  - ReadWriteOnce
resources:
  requests:
    {{- if $k3s }}
    storage: {{ $p.localVolumeSize }}
    {{- else if $static }}
    storage: {{ $p.AWS_ElasticBlockStore_size }}
    {{- else }}
    storage: {{ $p.size }}
    {{- end }}
{{- end -}}

{{/*
Owner check for a static hostPath folder (storageProvider k3s, staticHostPath).
Two databases on one folder corrupt it, and Postgres' own postmaster.pid lock
does not catch it across containers: each has its own PIDs, so the second one
takes the lock for stale. This init container writes <folder>/.owner with
<namespace>/<release>/<component> and refuses to start if another owner is
already there. A restart of the same component passes.

To hand a folder to another stack on purpose, delete <folder>/.owner on the node.

Renders init container list items, or nothing when the check does not apply.
Takes (dict "root" . "values" .Values.<component> "component" "<name>" "volume" "<volume name>").
*/}}
{{- define "osm-seed.volume.owner" -}}
{{- $p := .values.persistenceDisk -}}
{{- if and $p.enabled (eq (include "osm-seed.storageProvider" .root) "k3s") $p.staticHostPath }}
- name: volume-owner
  image: busybox:1.36
  securityContext:
    runAsUser: 0
  command: ["sh", "-c"]
  args:
    - |
      me="{{ .root.Release.Namespace }}/{{ .root.Release.Name }}/{{ .component }}"
      f=/volume/.owner
      if [ -f "$f" ] && [ "$(cat "$f")" != "$me" ]; then
        echo "error: {{ $p.localVolumeHostPath }} belongs to $(cat "$f"), not $me." >&2
        echo "       Two databases on one folder corrupt it. Use another localVolumeHostPath," >&2
        echo "       or, if the other one is gone for good, delete {{ $p.localVolumeHostPath }}/.owner on the node." >&2
        exit 1
      fi
      echo "$me" > "$f"
      echo "==> {{ $p.localVolumeHostPath }} belongs to $me"
  volumeMounts:
    - name: {{ .volume }}
      mountPath: /volume
{{- end }}
{{- end -}}
