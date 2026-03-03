moved {
  from = helm_release.traefik
  to   = helm_release.traefik[0]
}

moved {
  from = helm_release.traefik_options
  to   = helm_release.traefik_options[0]
}
