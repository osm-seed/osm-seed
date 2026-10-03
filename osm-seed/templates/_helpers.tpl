{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "osm-seed.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "osm-seed.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "osm-seed.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Container resources. Renders the "resources" key only when the component sets it.
Usage: {{- include "osm-seed.resources" .Values.webApi | nindent 10 }}
*/}}
{{- define "osm-seed.resources" -}}
{{- with .resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Node selector. Renders the "nodeSelector" key only when the component sets it.
Usage: {{- include "osm-seed.nodeSelector" .Values.webApi | nindent 6 }}
*/}}
{{- define "osm-seed.nodeSelector" -}}
{{- with .nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Pod affinity: node affinity from <component>.nodeAffinity and, when the component has it,
pod anti-affinity from <component>.podAntiAffinity (one pod per node).
Usage: {{- include "osm-seed.affinity" (dict "root" . "values" .Values.webApi "component" "web-api") | nindent 6 }}
*/}}
{{- define "osm-seed.affinity" -}}
{{- $v := .values -}}
{{- $anti := and $v.podAntiAffinity $v.podAntiAffinity.enabled -}}
{{- if or $v.nodeAffinity.enabled $anti }}
affinity:
  {{- if $v.nodeAffinity.enabled }}
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: {{ $v.nodeAffinity.key }}
              operator: In
              values:
              {{- range $v.nodeAffinity.values }}
                - {{ . | quote }}
              {{- end }}
  {{- end }}
  {{- if $anti }}
  # Preferred, not required: pods spread over nodes when there are several, but
  # with a single node a rollout can still start the new pod next to the old one.
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: {{ template "osm-seed.name" .root }}
              release: {{ .root.Release.Name }}
              run: {{ .root.Release.Name }}-{{ .component }}
          topologyKey: "kubernetes.io/hostname"
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Node affinity only. Usage: {{- include "osm-seed.nodeAffinity" .Values.memcached | nindent 6 }}
*/}}
{{- define "osm-seed.nodeAffinity" -}}
{{- include "osm-seed.affinity" (dict "values" .) -}}
{{- end -}}

{{/*
Service account for the pod, when <component>.serviceAccount.enabled is true.
Usage: {{- include "osm-seed.serviceAccount" .Values.webApi | nindent 6 }}
*/}}
{{- define "osm-seed.serviceAccount" -}}
{{- if and .serviceAccount .serviceAccount.enabled }}
serviceAccountName: {{ .serviceAccount.name }}
automountServiceAccountToken: true
{{- end }}
{{- end -}}

{{/*
Env vars that tell jobs where to upload files, per cloudProvider.
Usage: {{- include "osm-seed.cloudEnv" . | nindent 12 }}
*/}}
{{- define "osm-seed.cloudEnv" -}}
{{- if eq .Values.cloudProvider "aws" }}
- name: AWS_S3_BUCKET
  value: {{ .Values.AWS_S3_BUCKET }}
{{- end }}
{{- end -}}
