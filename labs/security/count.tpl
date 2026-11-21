{{- range . }}{{ .Target }}: {{ len .Vulnerabilities }}
{{ end -}}
