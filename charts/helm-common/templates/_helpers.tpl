{{/*
Expand the name of the chart.
*/}}
{{- define "unikorn.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "unikorn.fullname" -}}
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
{{- define "unikorn.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
These must be applied to every resource.
*/}}
{{- define "unikorn.labels" -}}
helm.sh/chart: {{ include "unikorn.chart" . }}
{{ include "unikorn.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "unikorn.selectorLabels" -}}
app.kubernetes.io/name: {{ include "unikorn.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Container image pull secrets.
This can be specified at the global level for every deployment, or overidden
on a per deployment basis.
*/}}
{{- define "unikorn.imagePullSecrets" -}}
{{- if .Values.imagePullSecret -}}
- name: {{ .Values.imagePullSecret -}}
{{- else if ( and .Values.global .Values.global.imagePullSecret ) -}}
- name: {{ .Values.global.imagePullSecret }}
{{- end }}
{{- end }}

{{/*
Container images.
*/}}
{{- define "unikorn.defaultRepositoryPath" -}}
{{- if .Values.repository }}
{{- printf "%s/%s" .Values.repository .Values.organization }}
{{- else }}
{{- .Values.organization }}
{{- end }}
{{- end }}

{{/*
Prometheus support.
These are used to label services and then as selectors in ServiceMonitors.
*/}}
{{- define "unikorn.prometheusServiceSelector" -}}
prometheus.unikorn-cloud.org/app: {{ include "unikorn.name" . }}
{{- end }}

{{- define "unikorn.prometheusJobLabel" -}}
prometheus.unikorn-cloud.org/job
{{- end }}

{{- define "unikorn.prometheusLabels" -}}
{{ include "unikorn.prometheusServiceSelector" . }}
{{ include "unikorn.prometheusJobLabel" . }}: {{ .job }}
{{- end }}

{{/*
OTLP support.
Used to configure tracing across all components.
*/}}
{{- define "unikorn.otlp.flags" -}}
{{- $otlp := .Values.otlp -}}
{{- if ( and .Values.global .Values.global.otlp ) -}}
{{- $otlp = .Values.global.otlp -}}
{{- end -}}
{{- if $otlp -}}
{{- with $endpoint := $otlp.endpoint }}
- --otlp-endpoint={{ $endpoint }}
{{- end }}
{{- end }}
{{- end }}

{{/*
CORS support.
Used to lock down APIs to specific clients.
*/}}
{{- define "unikorn.cors.flags" -}}
{{- $cors := .Values.cors -}}
{{- if ( and .Values.global .Values.global.cors ) -}}
{{- $cors = .Values.global.cors -}}
{{- end -}}
{{- if $cors -}}
{{- range $origin := $cors.allowOrigin }}
- --cors-allow-origin={{ $origin }}
{{- end -}}
{{- with $maxAge := $cors.maxAge }}
- --cors-max-age={{ $maxAge }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Creates predicatable Kubernetes name compatible UUIDs from name.
Note we always start with a letter (kubernetes DNS label requirement),
group 3 starts with "4" (UUIDv4 aka "random") and group 4 with "8"
(the variant aka RFC9562).
*/}}
{{ define "resource.id" -}}
{{- $sum := sha256sum . -}}
{{ printf "f%s-%s-4%s-8%s-%s" (substr 1 8 $sum) (substr 8 12 $sum) (substr 13 16 $sum) (substr 17 20 $sum) (substr 20 32 $sum) }}
{{- end }}

{{/*
Unified X.509 issuer.
This is used by Ingress resources to define the single source of TLS authority.
*/}}
{{- define "unikorn.ingress.clusterIssuer" -}}
{{- if (and .Values.global .Values.global.ingress .Values.global.ingress.clusterIssuer) -}}
{{- .Values.global.ingress.clusterIssuer }}
{{- else if .Values.ingress.clusterIssuer }}
{{- .Values.ingress.clusterIssuer }}
{{- end }}
{{- end }}

{{- define "unikorn.ingress.clusterIssuer.annotations" -}}
{{- with $issuer := (include "unikorn.ingress.clusterIssuer" .) -}}
cert-manager.io/cluster-issuer: {{ $issuer }}
{{- end }}
{{- end }}

{{/*
Unified DDNS.
*/}}
{{- define "unikorn.ingress.externalDNS" -}}
{{- if (and .Values.global .Values.global.ingress .Values.global.ingress.externalDNS) -}}
{{- .Values.global.ingress.externalDNS }}
{{- end }}
{{- end }}

{{/*
Unified X.509 authority.
This is used by services to get access to a self-signed TLS CA.
Typically you will reference cert-manager/unikorn-ca for the built in certificate
however you could also create a shared secret for things like letsencrypt-staging
where you want to use ACME, but don't want to make is widely structed by browsers.
*/}}
{{- define "unikorn.ca.secretNamespace" -}}
{{- if (and .Values.global .Values.global.ca .Values.global.ca.secretNamespace) -}}
{{- .Values.global.ca.secretNamespace }}
{{- else if (and .Values.ca .Values.ca.secretNamespace) -}}
{{- .Values.ca.secretNamespace }}
{{- end }}
{{- end }}

{{- define "unikorn.ca.secretName" -}}
{{- if (and .Values.global .Values.global.ca .Values.global.ca.secretName) -}}
{{- .Values.global.ca.secretName }}
{{- else if (and .Values.ca .Values.ca.secretName) -}}
{{- .Values.ca.secretName }}
{{- end }}
{{- end }}

{{/*
Unified X.509 client certificate.
This is used by services to authenticate against identity in order to grant an
oauth2 token for use with other services.
*/}}
{{- define "unikorn.clientCertificate.secretNamespace" -}}
{{- if (and .Values.clientCertificate .Values.clientCertificate.secretNamespace) -}}
{{- .Values.clientCertificate.secretNamespace }}
{{- end }}
{{- end }}

{{- define "unikorn.clientCertificate.secretName" -}}
{{- if (and .Values.clientCertificate .Values.clientCertificate.secretName) -}}
{{- .Values.clientCertificate.secretName }}
{{- end }}
{{- end }}

{{/*
Unified mTLS ingress handling.
APIs may accept client certificates to prove ownership of a bound access token,
thus the ingress client verification is optional.
Please note that all client CAs need to be sourced from the ingress' namespace
as the controller will reject you being able to access any secret in the system!
The CA comes for free with a cert-manager client certificate.
*/}}
{{- define "unikorn.mtls.certificate-name" -}}
{{ .Release.Name }}-client-certificate
{{- end }}

{{- define "unikorn.ingress.mtls.annotations" -}}
nginx.ingress.kubernetes.io/auth-tls-verify-client: optional
nginx.ingress.kubernetes.io/auth-tls-secret: {{ .Release.Namespace }}/{{ include "unikorn.mtls.certificate-name" . }}
nginx.ingress.kubernetes.io/auth-tls-verify-depth: "1"
nginx.ingress.kubernetes.io/auth-tls-pass-certificate-to-upstream: "true"
{{- end }}

{{- define "unikorn.mtls.flags" -}}
- --client-certificate-namespace={{ .Release.Namespace }}
- --client-certificate-name={{ include "unikorn.mtls.certificate-name" . }}
{{- end }}

{{/*
Unified service definitions.
These are typically used by services that rely on other services to function
and therefore need to get access to the hostname and TLS verification information.
We can therefore at a global level define these values just once and have them used
across all charts.  This also unifies the experience across all charts so things
are predictable, and less likely to break.
*/}}
{{- define "unikorn.identity.host" -}}
{{- if (and .Values.global .Values.global.identity .Values.global.identity.host) -}}
{{- .Values.global.identity.host }}
{{- else }}
{{- .Values.identity.host }}
{{- end }}
{{- end }}

{{- define "unikorn.region.host" -}}
{{- if (and .Values.global .Values.global.region .Values.global.region.host) -}}
{{- .Values.global.region.host }}
{{- else }}
{{- .Values.region.host }}
{{- end }}
{{- end }}

{{- define "unikorn.kubernetes.host" -}}
{{- if (and .Values.global .Values.global.kubernetes .Values.global.kubernetes.host) -}}
{{- .Values.global.kubernetes.host }}
{{- else }}
{{- .Values.kubernetes.host }}
{{- end }}
{{- end }}

{{- define "unikorn.compute.host" -}}
{{- if (and .Values.global .Values.global.compute .Values.global.compute.host) -}}
{{- .Values.global.compute.host }}
{{- else }}
{{- .Values.compute.host }}
{{- end }}
{{- end }}

{{- define "unikorn.application.host" -}}
{{- if (and .Values.global .Values.global.application .Values.global.application.host) -}}
{{- .Values.global.application.host }}
{{- else }}
{{- .Values.application.host }}
{{- end }}
{{- end }}

{{/*
Unified service flags.
As all components use the same client libraries, they have the same flags.
*/}}
{{- define "unikorn.core.flags" -}}
- --namespace={{ .Release.Namespace }}
{{- end }}

{{- define "unikorn.identity.flags" -}}
- --identity-host=https://{{ include "unikorn.identity.host" . }}
{{- with $namespace := ( include "unikorn.ca.secretNamespace" . ) }}
- --identity-ca-secret-namespace={{ $namespace }}
{{- end }}
{{- with $name := ( include "unikorn.ca.secretName" . ) }}
- --identity-ca-secret-name={{ $name }}
{{- end }}
{{- end }}

{{- define "unikorn.region.flags" -}}
- --region-host=https://{{ include "unikorn.region.host" . }}
{{- with $namespace := ( include "unikorn.ca.secretNamespace" . ) }}
- --region-ca-secret-namespace={{ $namespace }}
{{- end }}
{{- with $name := ( include "unikorn.ca.secretName" . ) }}
- --region-ca-secret-name={{ $name }}
{{- end }}
{{- end }}

{{- define "unikorn.clientCertificate.flags" -}}
{{- with $namespace := ( include "unikorn.clientCertificate.secretNamespace" . ) }}
- --client-certificate-namespace={{ $namespace }}
{{- end }}
{{- with $name := ( include "unikorn.clientCertificate.secretName" . ) }}
- --client-certificate-name={{ $name }}
{{- end }}
{{- end }}
