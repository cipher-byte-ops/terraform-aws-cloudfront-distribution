# Run only by the nightly integration workflow, against real cloud credentials.
# The example fronts a custom origin on the distribution's own domain, so it needs no certificate.
run "apply_minimal" {
  command = apply

  module {
    source = "./examples/minimal"
  }

  assert {
    condition     = output.domain_name != null
    error_message = "the distribution must be created and expose its domain name."
  }
}
