# Cookbook:: gitlab-patroni
# Recipe:: patroni
# License:: MIT
#
# Copyright:: 2018, GitLab Inc.

postgresql_helper           = GitlabPatroni::PostgresqlHelper.new(node)
config_directory            = node['gitlab-patroni']['patroni']['config_directory']
install_directory           = node['gitlab-patroni']['patroni']['install_directory']
log_directory               = node['gitlab-patroni']['patroni']['log_directory']
log_path                    = "#{log_directory}/patroni.log"
postgresql_config_directory = node['gitlab-patroni']['postgresql']['config_directory']
postgresql_user_home        = node['gitlab-patroni']['postgresql']['pg_user_homedir'].nil? ? postgresql_config_directory : node['gitlab-patroni']['postgresql']['pg_user_homedir']
postgresql_log_directory    = node['gitlab-patroni']['postgresql']['log_directory']
postgresql_log_path         = "#{postgresql_log_directory}/postgresql.log"
postgresql_csvlog_path      = "#{postgresql_log_directory}/postgresql.csv"
postgresql_superuser        = node['gitlab-patroni']['patroni']['users']['superuser']['username']
patroni_config_path         = "#{config_directory}/patroni.yml"
gitlab_patronictl_path      = '/usr/local/bin/gitlab-patronictl'
gitlab_pg_activity_path     = '/usr/local/bin/gitlab-pg_activity'
wale_log_path               = "#{postgresql_log_directory}/wale.log"
postgresql_syslog_logging   = node['gitlab-patroni']['postgresql']['parameters']['log_destination'] == 'syslog'
is_patroni_running_command  = "systemctl status patroni && #{gitlab_patronictl_path} list | grep #{node.name} | grep running"
alter_user_query            = "ALTER USER \"#{postgresql_superuser}\" SET statement_timeout=0"

postgresql_superuser_password = node['gitlab-patroni']['patroni']['users']['superuser']['password']

package 'build-essential'

python_runtime node['gitlab-patroni']['patroni']['python_runtime_version'] do
  pip_version node['gitlab-patroni']['patroni']['pip_version']
  get_pip_url node['gitlab-patroni']['patroni']['get_pip_url']
  options :system, package_name: node['gitlab-patroni']['patroni']['python_package_name']
end

python_virtualenv install_directory do
  pip_version node['gitlab-patroni']['patroni']['pip_version']
  get_pip_url node['gitlab-patroni']['patroni']['get_pip_url']
end

python_package 'psycopg2' do
  version node['gitlab-patroni']['patroni']['psycopg2_version']
end

python_package 'pg_activity' do
  version node['gitlab-patroni']['patroni']['pg_activity_version']
end

python_package 'certifi' do
  version node['gitlab-patroni']['patroni']['certifi_version']
end

python_package 'patroni[consul]' do
  version node['gitlab-patroni']['patroni']['version']
end

package 'runit'

directory config_directory do
  recursive true
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

if node['gitlab-patroni']['patroni']['use_custom_scripts']
  include_recipe '::custom_scripts'
end

template '/usr/local/bin/gitlab-psql' do
  source 'gitlab-psql.erb'
  variables(
    postgresql_user: postgresql_helper.postgresql_user,
    port: postgresql_helper.postgresql_port,
    host: 'localhost',
    superuser: postgresql_superuser,
    db_name: postgresql_helper.postgresql_db_name
  )
  mode '0777'
end

template gitlab_patronictl_path do
  source 'gitlab-patronictl.erb'
  variables(
    postgresql_user: postgresql_helper.postgresql_user,
    install_directory: install_directory,
    config_path: patroni_config_path
  )
  mode '0777'
end

cookbook_file "#{gitlab_pg_activity_path}" do
  source 'gitlab-pg_activity.sh'
  mode '0777'
end

file patroni_config_path do
  content YAML.dump(node['gitlab-patroni']['patroni']['config'].to_hash)
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  mode '0600'
  notifies :reload, 'poise_service[patroni]', :delayed
end

execute 'update bootstrap config' do
  command <<-CMD
#{install_directory}/bin/patronictl -c #{patroni_config_path} edit-config --force --replace - <<-YML
#{YAML.dump(node['gitlab-patroni']['patroni']['config']['bootstrap']['dcs'].to_hash)}
YML
  CMD
  # patronictl edit-config fails (for some reason) if the state is not in a running state
  only_if is_patroni_running_command
end

execute 'disable statement_timeout for superuser' do
  command "#{install_directory}/bin/patronictl -c #{patroni_config_path} query --role master --command '#{alter_user_query}' --username #{postgresql_superuser} --dbname postgres"
  environment(
    'PGPASSWORD' => postgresql_superuser_password
  )
  only_if is_patroni_running_command
end

poise_service 'patroni' do
  command ''
  provider :systemd
  options :systemd, template: 'patroni.systemd.erb', never_start: true, never_restart: true
end

service 'rsyslog' do
  supports [:restart]
end

directory log_directory do
  recursive true
  owner 'syslog'
  group 'syslog'
end

template '/etc/rsyslog.d/50-patroni.conf' do
  source 'rsyslog.conf.erb'
  variables(
    program_name: 'patroni',
    log_path: log_path
  )
  notifies :restart, 'service[rsyslog]', :delayed
end

if postgresql_syslog_logging
  template '/etc/rsyslog.d/51-postgresql.conf' do
    source 'rsyslog.conf.erb'
    variables(
      program_name: 'postgres',
      log_path: postgresql_log_path
    )
    notifies :restart, 'service[rsyslog]', :delayed
  end

  directory postgresql_log_directory do
    recursive true
    owner 'syslog'
    group 'syslog'
  end
else
  file '/etc/rsyslog.d/51-postgresql.conf' do
    action :delete
    notifies :restart, 'service[rsyslog]', :delayed
  end

  directory postgresql_log_directory do
    recursive true
    owner postgresql_helper.postgresql_user
    group postgresql_helper.postgresql_group
  end

  file "#{postgresql_log_directory}/#{node['gitlab-patroni']['postgresql']['parameters']['log_filename'] || 'postgresql.log'}" do
    owner postgresql_helper.postgresql_user
    group postgresql_helper.postgresql_group
  end
end

template '/etc/rsyslog.d/52-wale.conf' do
  source 'wale-rsyslog.conf.erb'
  variables(
    log_path: wale_log_path
  )
  notifies :restart, 'service[rsyslog]', :delayed
end

template "#{postgresql_user_home}/.pgpass" do
  source 'pgpass.erb'
  variables(
    hostname: 'localhost',
    port: postgresql_helper.postgresql_port,
    database: '*',
    username: postgresql_superuser,
    password: postgresql_superuser_password
  )
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  mode '0600'
  sensitive true
end

include_recipe 'logrotate::default'

{
  patroni: log_path,
  wale: wale_log_path
}.each do |app, app_path|
  logrotate_app app do
    path app_path
    options %w(missingok compress delaycompress notifempty)
    rotate 7
    frequency 'daily'
  end
end

logrotate_options = %w(missingok compress delaycompress notifempty)
logrotate_options << 'copytruncate' unless postgresql_syslog_logging

logrotate_app :postgresql do
  path [postgresql_log_path, postgresql_csvlog_path]
  options logrotate_options
  rotate 7
  frequency 'daily'
end
