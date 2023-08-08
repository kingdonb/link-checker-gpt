This link checker is designed for use with the FluxCD website preview environments:

```ruby
ruby link_checker.rb deploy-preview-1573--fluxcd.netlify.app
```

It may behave differently when run against `fluxcd.io` and the preview site,
but any differences are bugs. We either fix it here, or we fix the reason in
the website itself (probably by replacing an absolute link with a hard domain
reference to fluxcd.io in it.)

Assuming it runs to completion, it will produce a report in report.csv

I can import this report into Google Drive and mark it up as I fix the links.

At some point this could be improved to work as a CI check, but we will need
to fix most of the links first, and find a way to make exceptions for any more
that cannot be fixed.

There is a cache, so if you have run the script before the "Visiting links"
step will not be repeated unless you run `make clean` first. This is to help
with iterative development, since most of the runtime errors come from the
validate method and anchor checker, they can be debugged easily from a cache.
