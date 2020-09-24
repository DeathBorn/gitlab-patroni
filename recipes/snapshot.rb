postgresql_helper    = GitlabPatroni::PostgresqlHelper.new(node)
gcs_credentials_path = node['gitlab-patroni']['snapshot']['gcs_credentials_path']
snapshot_script_path = node['gitlab-patroni']['snapshot']['snapshot_script_path']
log_path_prefix      = node['gitlab-patroni']['snapshot']['log_path_prefix']

directory File.dirname(gcs_credentials_path) do
  recursive true
end

file gcs_credentials_path do
  content Base64.decode64(node['gitlab-patroni']['snapshot']['gcs_credentials'])
  mode '0600'
  sensitive true
  owner postgresql_helper.postgresql_user
end

template snapshot_script_path do
  source 'gcs-snapshot.sh.erb'
  variables(
    gcs_credentials_path: gcs_credentials_path,
    log_path_prefix: log_path_prefix
  )
  mode '0777'
end

cron 'GCS snapshot' do
  minute node['gitlab-patroni']['snapshot']['cron']['minute']
  hour node['gitlab-patroni']['snapshot']['cron']['hour']
  user postgresql_helper.postgresql_user
  command snapshot_script_path
  path '/usr/local/sbin:/usr/sbin/:/sbin:/usr/local/bin:/usr/bin:/bin'
  action :create
end

include_recipe 'logrotate::default'

logrotate_app :gcs_snapshot do
  path "#{log_path_prefix}*.log"
  options %w(missingok compress delaycompress notifempty)
  rotate 7
  frequency 'daily'
end
