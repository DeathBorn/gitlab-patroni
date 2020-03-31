source 'https://supermarket.chef.io'

metadata

cookbook 'gitlab_secrets', '~> 0.0.0', git: 'git@ops.gitlab.net:gitlab-cookbooks/gitlab_secrets.git'
cookbook 'consul', '~> 3.1.3', git: 'git@ops.gitlab.net:gitlab-cookbooks/consul.git'

group :test do
  cookbook 'gitlab_consul', '~> 1.0.2', git: 'git@ops.gitlab.net:gitlab-cookbooks/gitlab_consul.git'
end
