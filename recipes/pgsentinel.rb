# Cookbook:: gitlab-patroni
# Recipe:: pgsentinel
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
# Install the pgsentinel package from aptly.gitlab.com.

# GitLab Aptly repository is provisioned in postgresql recipe.
apt_package 'gitlab-pgsentinel' do
  action :install
end
