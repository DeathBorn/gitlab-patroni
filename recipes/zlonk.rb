zlonk_dir = node['gitlab-patroni']['zlonk']['directory']
project = node['gitlab-patroni']['zlonk']['project']
instance = node['gitlab-patroni']['zlonk']['instance']
log_dir = node['gitlab-patroni']['zlonk']['log_directory']

directory zlonk_dir do
  owner node['gitlab-patroni']['user']
  group node['gitlab-patroni']['group']
  mode '0755'
  recursive true
end

git zlonk_dir do
  repository node['gitlab-patroni']['zlonk']['git-http']
  revision node['gitlab-patroni']['zlonk']['branch']
  user node['gitlab-patroni']['user']
  action :sync
end

file "#{zlonk_dir}/bin/zlonk.sh" do
  mode '0755'
end

directory "#{log_dir}/#{project}/#{instance}" do
  recursive true
end

cron 'zlonk create' do
  command "#{zlonk_dir}/bin/zlonk.sh #{project} #{instance} >> #{log_dir}/#{project}/#{instance}/zlonk.log 2>&1"
  hour '21'
  minute '45'
  only_if { node['gitlab-patroni']['zlonk']['enabled'] }
end

cron 'zlonk destroy' do
  command "#{zlonk_dir}/bin/zlonk.sh #{project} #{instance} >> #{log_dir}/#{project}/#{instance}/zlonk.log 2>&1"
  hour '21'
  minute '30'
  only_if { node['gitlab-patroni']['zlonk']['enabled'] }
end
