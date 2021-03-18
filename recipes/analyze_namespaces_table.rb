postgresql_helper   = GitlabPatroni::PostgresqlHelper.new(node)
analyze_script_path = node['gitlab-patroni']['analyze']['analyze_script_path']
log_path_prefix     = node['gitlab-patroni']['analyze']['log_path_prefix']

file 'files/default/analyze-namespaces-table.sh' do
  content File.read('files/default/analyze-namespaces-table.sh')
  path analyze_script_path
  mode '0777'
end

cron 'analyze_namespaces_table' do
  minute node['gitlab-patroni']['analyze']['cron']['minute']
  hour node['gitlab-patroni']['analyze']['cron']['hour']
  user postgresql_helper.postgresql_user
  command analyze_script_path
  path '/usr/local/sbin:/usr/sbin/:/sbin:/usr/local/bin:/usr/bin:/bin'
  action :create
end

include_recipe 'logrotate::default'

logrotate_app :analyze_namespaces_table do
  path "#{log_path_prefix}*.log"
  options %w(missingok compress delaycompress notifempty)
  rotate 7
  frequency 'daily'
end
