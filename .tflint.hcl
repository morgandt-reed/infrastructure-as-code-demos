# Bundled Terraform ruleset, "recommended" preset. No provider plugin, so this
# runs without network access and without AWS credentials.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
