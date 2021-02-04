# Cookbook:: gitlab-patroni
# Recipe:: pgsentinel
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
# Install the pgsentinel package from aptly.gitlab.com.

apt_repository 'gitlab-aptly' do
  uri          'http://aptly.gitlab.com/gitlab-utils'
  arch         'amd64'
  distribution 'xenial'
  components   ['main']
  key          'http://aptly.gitlab.com/release.asc'
end

apt_package 'gitlab-pgsentinel' do
  action :install
end
