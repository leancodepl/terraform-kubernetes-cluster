moved {
  from = helm_release.external_dns
  to   = helm_release.external_dns[0]
}
