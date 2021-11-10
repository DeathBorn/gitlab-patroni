postgresql_helper = GitlabPatroni::PostgresqlHelper.new(node)
reset_sampling_script_path = node['gitlab-patroni']['reset_sampling']['reset_sampling_script_path']
log_path_prefix = node['gitlab-patroni']['reset_sampling']['log_path_prefix']

cookbook_file reset_sampling_script_path do
  source File.basename(name)
  mode '0777'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

cron 'reset_sampling' do
  minute node['gitlab-patroni']['reset_sampling']['cron']['minute']
  hour node['gitlab-patroni']['reset_sampling']['cron']['hour']
  day node['gitlab-patroni']['reset_sampling']['cron']['hour']
  user postgresql_helper.postgresql_user
  command reset_sampling_script_path
  path '/usr/local/sbin:/usr/sbin/:/sbin:/usr/local/bin:/usr/bin:/bin'
  action :create
end

include_recipe 'logrotate::default'

logrotate_app :reset_sampling do
  path "#{log_path_prefix}*.log"
  options %w(missingok compress delaycompress notifempty)
  rotate 7
  frequency 'daily'
end
