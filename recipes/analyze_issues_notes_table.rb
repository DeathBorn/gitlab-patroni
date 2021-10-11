postgresql_helper   = GitlabPatroni::PostgresqlHelper.new(node)
analyze_script_path = node['gitlab-patroni']['issues_notes']['analyze_script_path']
log_path_prefix     = node['gitlab-patroni']['issues_notes']['log_path_prefix']

cookbook_file analyze_script_path do
  source File.basename(name)
  mode '0777'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

cron 'analyze_issues_notes_table' do
  minute node['gitlab-patroni']['issues_notes']['cron']['minute']
  hour node['gitlab-patroni']['issues_notes']['cron']['hour']
  user postgresql_helper.postgresql_user
  command analyze_script_path
  path '/usr/local/sbin:/usr/sbin/:/sbin:/usr/local/bin:/usr/bin:/bin'
  action :create
end

include_recipe 'logrotate::default'

logrotate_app :analyze_issues_notes_table do
  path "#{log_path_prefix}*.log"
  options %w(missingok compress delaycompress notifempty)
  rotate 7
  frequency 'daily'
end
