{{/*
Expand the name of the chart.
*/}}
{{- define "remnawave-subscription-page.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "remnawave-subscription-page.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "remnawave-subscription-page.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "remnawave-subscription-page.labels" -}}
helm.sh/chart: {{ include "remnawave-subscription-page.chart" . }}
{{ include "remnawave-subscription-page.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "remnawave-subscription-page.selectorLabels" -}}
app.kubernetes.io/name: {{ include "remnawave-subscription-page.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "remnawave-subscription-page.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "remnawave-subscription-page.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
TLS secret name for ingress
*/}}
{{- define "remnawave-subscription-page.tlsSecretName" -}}
{{- if .Values.ingress.tlsSecretName }}
{{- .Values.ingress.tlsSecretName }}
{{- else }}
{{- printf "%s-tls" .Values.ingress.host }}
{{- end }}
{{- end }}
