[![build status](https://gitlab.com/gitlab-cookbooks/gitlab-patroni/badges/master/build.svg)](https://gitlab.com/gitlab-cookbooks/gitlab-patroni/commits/master)
[![coverage report](https://gitlab.com/gitlab-cookbooks/gitlab-patroni/badges/master/coverage.svg)](https://gitlab.com/gitlab-cookbooks/gitlab-patroni/commits/master)

# gitlab-patroni

TODO: Remove this line. -- @nnelson, 2020-01-27

Installs and configures [Patroni](https://github.com/zalando/patroni) for GitLab infrastructure.

## Using

Describe how your cookbook should be used.

## Setting up a local cluster

We use [Kitchen](https://kitchen.ci/) to automate the creation of a local cluster.
Under the hood, Kitchen uses [Vagrant](https://www.vagrantup.com/) to provision
the virtual machines, so make sure you got it installed before you start.

By default we create a cluster of 3 nodes, if you want more, edit `.kitchen.yml`
and add more suite definitions under `suites`. Make sure to increment the private IP
number, to add the new IPs under `gitlab_consul.cluster_nodes`, and to update
`bootstrap_expect` value to match the new cluster count.

To create the cluster, run the following (add `-c <count>` after `create`/`converge` to
run the operation in parallel):

```
$ kitchen create all
$ export VAGRANT_INTERFACE_NAME=$(kitchen exec patroni-1 --no-color -c "ip -o -4 addr show | grep 192.168.33.2 | cut -f2 -d' '" | tail -1)
$ kitchen converge all
$ kitchen exec patroni -c 'sudo systemctl start patroni'
```

If Chef converges successfully, run `kitchen login patroni-<number>` to login to a cluster member.

If Consul, Patroni or Postgres are not running, look at their respective log files for any hints
(Consul logs to syslog, so use `sudo journalctl -xe _SYSTEMD_UNIT=consul.service` to fetch its logs).

If you can't find a solution, please open an issue in this project, attach `kitchen converge`, Consul,
Postgres, and Patroni logs to it, then assign it to a recent contributor of this project.

## Testing

The Makefile, which holds all the logic, is designed to be the same among all
cookbooks. Just set the comment at the top to include the cookbook name and
you are all set to use the below testing instructions.

### Testing locally

You can run `rspec` or `kitchen` tests directly without using provided
`Makefile`, although you can follow instructions to benefit from it.

1. Install GNU Make (`apt-get install make`). Under OS X you can achieve the
   same by `brew install make`. After this, you can see available targets of
   the Makefile just by running `make` in cookbook directory.

1. Cheat-sheet overview of current targets:

 * `make gems`: install latest version of required gems into directory,
   specified by environmental variable `BUNDLE_PATH`. By default it is set to
   the same directory as on CI, `.bundle`, in the same directory as Makefile
   is located.

 * `make check`: find all `*.rb` files in the current directory, excluding ones
   in `BUNDLE_PATH`, and check them with rubocop.

 * `make rspec`: the above, plus run all the rspec tests. You can use
   `bundle exec rspec -f d` to skip the lint step, but it is required on CI
   anyways, so rather please fix it early ;)

 * `make kitchen`: calculate the number of suites in `.kitchen.do.yml`, and
   run all integration tests, using the calculated number as a `concurrency`
   parameter. In order to this locally by default, copy the example kitchen
   config to your local one: `cp .kitchen.do.yml .kitchen.local.yml`, or
   export environmental variable: `export KITCHEN_YAML=".kitchen.do.yml"`

   *Note* that `.kitchen.yml` is left as a default Vagrant setup and is not
   used by Makefile.

1. In order to use DigitalOcean for integration testing locally, by using
   `make kitchen` or running `bundle exec kitchen test --destroy=always`,
   export the following variables according to the
   [kitchen-digitalocean](https://github.com/test-kitchen/kitchen-digitalocean)
   documentation:
  * `DIGITALOCEAN_ACCESS_TOKEN`
  * `DIGITALOCEAN_SSH_KEY_IDS`

### on CI

Alternatively, you can just push to your branch and let CI handle the testing.
To setup it, add the `DIGITALOCEAN_ACCESS_TOKEN` secret variable under your
project settings, `make kitchen` target will:
 * detect the CI environment
 * generate ephemeral SSH ed25519 keypair
 * register them on DigitalOcean
 * export the resulting key as `DIGITALOCEAN_SSH_KEY_IDS` environment variable
 * run the kitchen test
 * clean up the ephemeral key from DigitalOcean after pipeline is done

See `.gitlab-ci.yml` for details, but the overall goal is to have only
`make rspec` and `make kitchen` in it, and cache `$BUNDLE_PATH` for speed.

Since `make check` is a prerequisite for `make rspec`, current CI configuration
basically enforces all of the following to succeed, in defined order, for a
pipeline to pass:
 * Rubocop should be happy with every ruby file and exit with dcode zero,
   without any warnings or errors.
 * Rspec tests must all pass.
 * Integration tests must all pass.
