# Cookbook:: gitlab-patroni
# Recipe:: consul
# License:: MIT
#
# Copyright:: 2018, GitLab Inc.

# We can't have secrets merging inside `AttributesHelper` because `get_secrets` is not
# designed to work inside a module
secrets_hash = node['gitlab-patroni']['secrets']
secrets      = get_secrets(secrets_hash['backend'], secrets_hash['path'], secrets_hash['key'])
patroni_conf = node.to_hash
patroni_conf['gitlab-patroni'] = Chef::Mixin::DeepMerge.deep_merge(secrets['gitlab-patroni'], patroni_conf['gitlab-patroni']).to_hash
patroni_conf = GitlabPatroni::AttributesHelper.populate_missing_values(patroni_conf)

check_interval = patroni_conf['gitlab-patroni']['patroni']['consul']['check_interval']
service_name = patroni_conf['gitlab-patroni']['patroni']['consul']['service_name']

service 'consul' do
  supports [:reload]
end

consul_definition 'patroni' do
  type 'services'
  parameters(
    [
      {
        id: "#{service_name}-master",
        name: service_name,
        tags: [
          'master'
        ],
        checks: [
          {
            http: "http://#{patroni_conf['gitlab-patroni']['patroni']['config']['restapi']['listen']}/master",
            interval: check_interval
          }
        ].concat(patroni_conf['gitlab-patroni']['patroni']['consul']['extra_checks']['master'])
      },
      {
        id: "#{service_name}-replica",
        name: service_name,
        tags: [
          'replica'
        ],
        checks: [
          {
            http: "http://#{patroni_conf['gitlab-patroni']['patroni']['config']['restapi']['listen']}/replica",
            interval: check_interval
          }
        ].concat(patroni_conf['gitlab-patroni']['patroni']['consul']['extra_checks']['replica'])
      }
    ]
  )
  notifies :reload, 'service[consul]', :delayed
end
