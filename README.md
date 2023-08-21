# Link-Checker GPT

Welcome to the Link-Checker GPT! Crafted with the assistance of ChatGPT, this link checker ensures the integrity of links in your website's content. Although primarily designed for the FluxCD website's preview environments, it's versatile enough to work with most platforms, including Netlify.

## Integration as a CI Check

Link-Checker GPT is ready to be integrated as a CI check within the fluxcd/website repository. When a PR check flags an error, it's an invitation to refine your links. An associated report is available as a downloadable CSV to guide the necessary corrections. In the future, our bot might also add a comment to your PR, providing a gentle nag that aims to cajole us into eventually reduce the number of bad links in the repo all the way down to zero.

## Integration Guide for `fluxcd/website`

Integrating the Link-Checker GPT into your existing workflow is straightforward. Here's how you can integrate it into the `fluxcd/website` repository:

### Step 1: Add the Action

In your `.github/workflows/` directory (create it if it doesn't exist), add a new workflow file, for instance, `link-check.yml`. You can also add this in an existing workflow.

Within this file, add the following content:

```yaml
name: Link Checker

on:
  pull_request:
    branches:
      - main

jobs:
  check-links:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Link Checker GPT
      uses: kingdonb/link-checker-gpt@v1-beta # (the v1 tag is still unreleased, we need to test)
      with:
        productionDomain: fluxcd.io
        previewDomain: deploy-preview-${{ github.event.pull_request.number }}--fluxcd.netlify.app
        prNumber: ${{ github.event.pull_request.number }}
```

WIP - **TODO**: make this work for other consumers besides fluxcd.io - we have yet to test this on any other site. It should work anywhere that publishes a `sitemap.xml`, (which should be pretty much every important CMS including Jekyll, Hugo, Docsy, Bartholomew, ...)

### Step 2: Configuration

The required parameters are `productionDomain`, the target domain for production (to create a baseline report) and `previewDomain` the target domain for the PR's preview environment, by the convention this can usually be inferred from the PR number. This is the preview URL for the link checker.

Both domains must create a sitemap.xml and populate it.

### Step 3: Commit and Test

Commit the new workflow file and create a new pull request. The Link Checker GPT action should automatically run and validate the links within the website content associated with the PR.

If there are any bad links in the production site, they will be captured in a baseline report for follow-up later. Those links are not counted against a PR. If there are any new bad links in the PR then the check will fail.

(Create a link to an invalid anchor in your PR to test this works, then revert the change before merging it!)

## How it Works

Familiarize yourself with the moving parts in a local clone. This action is Dockerized, but it was not designed to run in Docker, it is a Ruby program and can run on your local workstation. Just run `bundle install` first, then type `make`!

(You will run against PR#1573 but in case you want to use a different PR to check for problems, you can just edit the Makefile, or keep reading to learn how to use this as a GitHub Action.)

To check the links of a preview environment on Netlify, simply run:

```bash
ruby main.rb deploy-preview-1573--fluxcd.netlify.app
```

This checks for bad links in your PR. But this is only half a check. We don't want you to get blamed for bad links that already were on the site, just because you opened a PR.

So the tool needs to check `fluxcd.io` first, count up those bad links, then discount them from the PR so we can get a valid check output. This way we should guarantee that no new PR ever adds bad links to the FluxCD.io website. Any discrepancies between the reports are considered bugs—either they represent an error in this tool or they can be addressed directly in the website by modifying the links.

There is a baseline report as well as a pr review report that tell what bad links are found, whether they are pre-existing on the site or created by your PR. Those pre-existing ones should be fixed eventually, as well, but they will not count against your PR.

Upon successful execution one single time, a report detailing the link statuses is generated in `report.csv`. You can import this CSV into tools like Google Drive for further analysis and action. The `make summary` process takes the normalized output of the above described two checks, and it returns an error from the `check_summary.sh` script if the build should pass or fail.

## Note on UX: Report Download

In the event of a PR check failure, you can read the report in the failed job output. Initially this workflow was designed to enable the user to access a detailed report in the form of a zipped CSV. This was originally built as a composite workflow, you can still find remnants of this in the commented section of `action.yml`.

Instead, the report now goes out to the workflow/action job log. You can read all the bad links created by your PR there. Any links from the baseline site will not be included in the report unless your PR is spotless. A later version might emit the baseline report when there is no issue created by the PR, to encourage tidying. Then the report will show the baseline issues, but since it was not caused by your PR they will not fail the report.

The primary goal is to maximize the signal to noise ratio and prevent the users from desiring to uninstall this workflow. It should be easy to adopt, and it should never fail the workflow to nag the contributor about issues that their PR didn't create.

**TODO**: We will still figure out a way to expose those baseline errors yet.

## Cache Management

The tool incorporates caching initially intended to expedite repeated runs. This could be particularly useful for iterative development. Most runtime errors, especially those from the validate method and anchor checkers, can be debugged efficiently using cached data without re-fetching anything.

However, there's a known issue: the cache isn't always reliable. To ensure accuracy, always run `make clean-cache` between separate executions. The cache is still used to prevent repeated calls out and to avoid the repeated loading of HTML files into memory. As a result, a lot of memory can be used.

**TODO**: We're considering refining the cache management system. The cache should always be invalidated unless its validity is assured. This feature's primary purpose is for one-time use and might be phased out or redesigned in future versions.

The primary issue to grapple now is that we can wait for the preview environment's deploy to become ready once, but cannot guarantee that subsequent runs of the checker are always looking at the latest version. There is no synchronization or coordination between independent jobs, and there is no job configuration for the Netlify preview build (not even sure how this works - it is an externally provided action.)

Perhaps we can read the check statuses and wait to proceed with the scan of the preview domain until the Netlify deploy check shows itself as ready.
