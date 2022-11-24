# Cookbook:: gitlab-patroni
# Recipe:: postgresql
# License:: MIT
#
# Copyright:: 2018, GitLab Inc.

postgresql_helper           = GitlabPatroni::PostgresqlHelper.new(node)
postgresql_config_directory = node['gitlab-patroni']['postgresql']['config_directory']

# Needed to support Postgres 12 as deployed on May 8: we need to de-couple gitlab-psql's
# home directory from the postgres config_directory; with conditional assigment, we will
# support the old way in older environment, the new way in newer environments
postgresql_user_home = node['gitlab-patroni']['postgresql']['pg_user_homedir'].nil? ? postgresql_config_directory : node['gitlab-patroni']['postgresql']['pg_user_homedir']

directory postgresql_user_home do
  recursive true
end

user postgresql_helper.postgresql_user do
  home postgresql_user_home
  not_if { node['etc']['passwd'].key?(postgresql_helper.postgresql_user) }
end

# When restoring from a disk snapshot, these two chown commands are necessary
# if the source disk has different uids than the server
execute "chown #{postgresql_user_home}" do
  command "chown -R #{postgresql_helper.postgresql_user}:#{postgresql_helper.postgresql_group} #{postgresql_user_home}"
  only_if { postgresql_helper.dir_exist_not_postgres_owned?(postgresql_user_home) }
end

execute "chown #{postgresql_config_directory}" do
  command "chown -R #{postgresql_helper.postgresql_user}:#{postgresql_helper.postgresql_group} #{postgresql_config_directory}"
  only_if { postgresql_helper.dir_exist_not_postgres_owned?(postgresql_config_directory) }
end

directory postgresql_user_home do
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

directory postgresql_config_directory do
  recursive true
  mode '0700'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

apt_update 'apt update'

# Adapted from the postgresql cookbook
package 'apt-transport-https'

apt_repository 'postgresql' do
  uri          'https://download.postgresql.org/pub/repos/apt/'
  components   ['main', postgresql_helper.version]
  distribution "#{node['lsb']['codename']}-pgdg"
  key 'https://download.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
  cache_rebuild true
end

# Used to install custom-built packages or packages that's not published in the default APT repositories
apt_repository 'gitlab-aptly' do
  uri          'http://aptly.gitlab.com/gitlab-utils'
  arch         'amd64'
  distribution 'xenial'
  components   ['main']
  key          'http://aptly.gitlab.com/release.asc'
  cache_rebuild true
end

use_gitlab_aptly = node['gitlab-patroni']['postgresql']['use_gitlab_aptly']
apt_preference 'postgresql' do
  glob 'postgresql-*'
  pin 'origin aptly.gitlab.com'
  pin_priority use_gitlab_aptly ? '1001' : '400'
end

package "postgresql-#{postgresql_helper.version}"

if node['gitlab-patroni']['postgresql']['install_debug_package']
  if node['lsb']['codename'] == 'xenial'
    if node['gitlab-patroni']['postgresql']['dbg_debug_package']
      package "postgresql-#{postgresql_helper.version}-dbg"
    else
      package "postgresql-#{postgresql_helper.version}-dbgsym"
    end
  else
    package "postgresql-#{postgresql_helper.version}-dbgsym"
  end
end

package "postgresql-#{postgresql_helper.version}-repack"
# Needed by psycopg2 >= 2.8 which is a dependency of Patroni
package "postgresql-server-dev-#{postgresql_helper.version}"

service 'postgresql' do
  action %i[stop disable]
end

cookbook_file "#{postgresql_config_directory}/postgresql.base.conf" do
  source 'postgresql.conf'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group

  # If this file already exists, manage it in Chef. If it doesn't, it means that:
  # a. We're adding a new node, in which case we want patroni to create the configuration
  # b. We're initializing a new cluster. Since this case is a rare occurrence, we leave
  # creating this file as a manual action (a simple `touch` is enough for chef to take
  # over).
  only_if { ::File.exist?(name) }
end

file "#{postgresql_user_home}/cacert.pem" do
  content node['gitlab-patroni']['postgresql']['ssl_ca']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

file "#{postgresql_user_home}/server.crt" do
  content node['gitlab-patroni']['postgresql']['ssl_cert']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

file "#{postgresql_user_home}/server.key" do
  content node['gitlab-patroni']['postgresql']['ssl_key']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

sysctl 'kernel.shmmax' do
  value node['gitlab-patroni']['postgresql']['shmmax']
end

sysctl 'kernel.shmall' do
  value node['gitlab-patroni']['postgresql']['shmall']
end

sem = [
  node['gitlab-patroni']['postgresql']['semmsl'],
  node['gitlab-patroni']['postgresql']['semmns'],
  node['gitlab-patroni']['postgresql']['semopm'],
  node['gitlab-patroni']['postgresql']['semmni'],
].join(' ')
sysctl 'kernel.sem' do
  value sem
end
