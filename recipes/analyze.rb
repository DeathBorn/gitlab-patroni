postgresql_helper    = GitlabPatroni::PostgresqlHelper.new(node)
snapshot_script_path = node['gitlab-patroni']['analyze']['analyze_script_path']
log_path_prefix      = node['gitlab-patroni']['analyze']['log_path_prefix']

template analyze_script_path do
  source 'analyze-table.sh.erb'
  variables(
    gcs_credentials_path: gcs_credentials_path,
    log_path_prefix: log_path_prefix
  )
  mode '0777'
end

cron 'DB_analyze_table' do
  minute node['gitlab-patroni']['analyze']['cron']['minute']
  hour node['gitlab-patroni']['analyze']['cron']['hour']
  user postgresql_helper.postgresql_user
  command analyze_script_path
  path '/usr/local/sbin:/usr/sbin/:/sbin:/usr/local/bin:/usr/bin:/bin'
  action :create
end

include_recipe 'logrotate::default'

logrotate_app :db_analyze do
  path "#{log_path_prefix}*.log"
  options %w(missingok compress delaycompress notifempty)
  rotate 7
  frequency 'daily'
end