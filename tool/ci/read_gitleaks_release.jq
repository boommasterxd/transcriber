(.tag_name
  | strings
  | capture("\\Av(?<version>(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*))\\z").version) as $version
| [.assets | arrays | .[] | select(.name == "gitleaks_\($version)_linux_x64.tar.gz")] as $assets
| if ($assets | length) != 1 then
    error("Expected one matching Gitleaks Linux x64 release archive.")
  else
    ($assets[0].digest | strings | select(test("\\Asha256:[a-f0-9]{64}\\z")) | ltrimstr("sha256:")) as $sha256
    | {version: $version, sha256: $sha256}
  end
