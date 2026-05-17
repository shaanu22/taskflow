{{- define "taskflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "taskflow.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "taskflow.labels" -}}
helm.sh/chart: {{ include "taskflow.name" . }}-{{ .Chart.Version }}
{{ include "taskflow.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "taskflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "taskflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
