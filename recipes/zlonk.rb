zlonk_dir = node['gitlab-patroni']['zlonk']['directory']

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

cron 'zlonk' do
  command ""
  hour '0'
  minute '0'
end
