# Cookbook Name:: gitlab-patroni
# Recipe:: consul
# License:: MIT
#
# Copyright 2018, GitLab Inc.

check_interval = node['gitlab-patroni']['patroni']['consul']['check_interval']
service_name = node['gitlab-patroni']['patroni']['consul']['service_name']

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
            http: "http://#{node['gitlab-patroni']['patroni']['config']['restapi']['listen']}/master",
            interval: check_interval
          }
        ].concat(node['gitlab-patroni']['patroni']['consul']['extra_checks']['master'])
      },
      {
        id: "#{service_name}-replica",
        name: service_name,
        tags: [
          'replica'
        ],
        checks: [
          {
            http: "http://#{node['gitlab-patroni']['patroni']['config']['restapi']['listen']}/replica",
            interval: check_interval
          }
        ].concat(node['gitlab-patroni']['patroni']['consul']['extra_checks']['replica'])
      }
    ]
  )
  notifies :reload, 'service[consul]', :delayed
end
