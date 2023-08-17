# Link-Checker GPT

This link checker is so-named because it was mostly written by ChatGPT.

It is designed for use with the FluxCD website preview environments (but it
could easily work with any Netlify or probably whatever other PaaS account):

```ruby
ruby main.rb deploy-preview-1573--fluxcd.netlify.app
```

It may behave differently when run against `fluxcd.io` and the preview site,
but any differences are bugs. We either fix it here, or we fix the reason in
the website itself (probably by replacing an absolute link with a hard domain
reference to fluxcd.io in it.)

Assuming it runs to completion, it will produce a report in report.csv

I can import this report into Google Drive and mark it up as I fix the links.

This nearly works as a CI check now! We still have to test it by including in
the fluxcd/website repository.

### Bad UX: Report Download

When the PR check fails, you can download a zip file with a CSV report in it.
The bot might also comment on your PR. It's trying to get you to reduce the
report noise. If you do what it says, then this ugly report will go away! ✅

TODO: We will fix this by minimizing the UI.

### Broken feature: Sitemap Caching

There is a cache, so if you have run the script before the "Visiting links"
step will not be repeated unless you run `make clean` first. This is to help
with iterative development, since most of the runtime errors come from the
validate method and anchor checker, they can be debugged easily from a cache.

However, it doesn't work. So make sure if you are running this more than one
time, you always run at least `make clean-cache` between separate executions.

TODO: We will remove the cache reuse, it should always be invalidated unless
it can be proven to still be valid. It's not needed except for one-time use.
