# Cookbook:: gitlab-patroni
# Recipe:: postgresql
# License:: MIT
#
# Copyright:: 2018, GitLab Inc.

# We can't have secrets merging inside `AttributesHelper` because `get_secrets` is not
# designed to work inside a module
secrets_hash = node['gitlab-patroni']['secrets']
secrets      = get_secrets(secrets_hash['backend'], secrets_hash['path'], secrets_hash['key'])
patroni_conf = node.to_hash
patroni_conf['gitlab-patroni'] = Chef::Mixin::DeepMerge.deep_merge(secrets['gitlab-patroni'], patroni_conf['gitlab-patroni'])
patroni_conf = GitlabPatroni::AttributesHelper.populate_missing_values(patroni_conf)

postgresql_helper           = GitlabPatroni::PostgresqlHelper.new(patroni_conf)
postgresql_config_directory = patroni_conf['gitlab-patroni']['postgresql']['config_directory']

directory postgresql_config_directory do
  recursive true
end

user postgresql_helper.postgresql_user do
  home postgresql_config_directory
  manage_home true
  not_if { patroni_conf['etc']['passwd'].key?(postgresql_helper.postgresql_user) }
end

directory postgresql_config_directory do
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

# Adapted from the postgresql cookbook
package 'apt-transport-https'

apt_repository 'postgresql' do
  uri          'https://download.postgresql.org/pub/repos/apt/'
  components   ['main', postgresql_helper.version]
  distribution "#{patroni_conf['lsb']['codename']}-pgdg"
  key 'https://download.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
  cache_rebuild true
end

package "postgresql-#{postgresql_helper.version}"
package "postgresql-#{postgresql_helper.version}-repack"
# Needed by psycopg2 >= 2.8 which is a dependency of Patroni
package "postgresql-server-dev-#{postgresql_helper.version}"

service 'postgresql' do
  action %i[stop disable]
end

cookbook_file "#{postgresql_config_directory}/postgresql.conf" do
  source File.basename(name)
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  # Patroni expects postgresql.conf to exist to move it to postgresql.base.conf,
  # managing postgresql.conf by itself, so we don't want to override it.
  action :create_if_missing
end

cookbook_file "#{postgresql_config_directory}/postgresql.base.conf" do
  source 'postgresql.conf'
  only_if { ::File.exist?(name) }
end

file "#{postgresql_config_directory}/cacert.pem" do
  content patroni_conf['gitlab-patroni']['postgresql']['ssl_ca']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

file "#{postgresql_config_directory}/server.crt" do
  content patroni_conf['gitlab-patroni']['postgresql']['ssl_cert']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

file "#{postgresql_config_directory}/server.key" do
  content patroni_conf['gitlab-patroni']['postgresql']['ssl_key']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

sysctl 'kernel.shmmax' do
  value patroni_conf['gitlab-patroni']['postgresql']['shmmax']
end

sysctl 'kernel.shmall' do
  value patroni_conf['gitlab-patroni']['postgresql']['shmall']
end

sem = [
  patroni_conf['gitlab-patroni']['postgresql']['semmsl'],
  patroni_conf['gitlab-patroni']['postgresql']['semmns'],
  patroni_conf['gitlab-patroni']['postgresql']['semopm'],
  patroni_conf['gitlab-patroni']['postgresql']['semmni'],
].join(' ')
sysctl 'kernel.sem' do
  value sem
end
