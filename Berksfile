source 'https://supermarket.chef.io'

metadata

cookbook 'gitlab_secrets', '~> 0.0.0', git: 'git@ops.gitlab.net:gitlab-cookbooks/gitlab_secrets.git'
cookbook 'golang', '= 3.0.1'
cookbook 'seven_zip', '~> 2.0'

group :test do
  cookbook 'gitlab_consul', '~> 1.1.3', git: 'git@ops.gitlab.net:gitlab-cookbooks/gitlab_consul.git'
end
