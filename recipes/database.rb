include_recipe "mysql::server"
include_recipe "mysql::ruby"


execute "mysql-install-mage-privileges" do
  command "/usr/bin/mysql -u root -p#{node[:mysql][:server_root_password]} < /etc/mysql/mage-grants.sql"
  action :nothing
end

template "/etc/mysql/mage-grants.sql" do
  path "/etc/mysql/mage-grants.sql"
  source "grants.sql.erb"
  owner "root"
  group "root"
  mode "0600"
  variables(:database => node[:magento][:db])
  notifies :run, resources(:execute => "mysql-install-mage-privileges"), :immediately
end

execute "create #{node[:magento][:db][:database]} database" do
  command "/usr/bin/mysqladmin -u root -p#{node[:mysql][:server_root_password]} create #{node[:magento][:db][:database]}"
  not_if do
    require 'rubygems'
    Gem.clear_paths
    require 'mysql'
    m = Mysql.new("localhost", "root", node[:mysql][:server_root_password])
    m.list_dbs.include?(node[:magento][:db][:database])
  end
end

# Import Sample Data
if node[:magento][:db][:sample_data] and !(File.exist?("#{node[:magento][:dir]}/sample.#{node[:magento][:sample_data_version]}"))

  user node[:magento][:user] do
    comment "magento guy"
    home node[:magento][:dir]
    system true
  end

  directory "#{node[:magento][:dir]}/sample_data" do
    owner node[:magento][:user]
    group node[:nginx][:group]
    mode "0755"
    action :create
    recursive true
  end

  remote_file "#{Chef::Config[:file_cache_path]}/magento-sample-data.tar.gz" do
    source node[:magento][:sample_data_url]
    mode "0644"
  end

  bash "magento-sample-data" do
    cwd "#{node[:magento][:dir]}/sample_data"
    code <<-EOH
      tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/magento-sample-data.tar.gz
      #rsync -a media/* #{node[:magento][:dir]}/media/
      mv magento_sample_data*.sql data.sql
      /usr/bin/mysql -h localhost -u #{node[:magento][:db][:username]} -p#{node[:magento][:db][:password]} #{node[:magento][:db][:database]} < data.sql
      cd ..
      rm -r -f #{node[:magento][:dir]}/sample_data
      EOH
  end

  bash "Touch #{node[:magento][:dir]}/sample.#{node[:magento][:sample_data_version]} flag" do
    cwd node[:magento][:dir]
    code <<-EOH
    touch #{node[:magento][:dir]}/sample.#{node[:magento][:sample_data_version]}
    EOH
  end

  bash "Ensure correct permissions & ownership" do
    cwd node[:magento][:dir]
    code <<-EOH
    chown -R #{node[:magento][:user]}:#{node[:nginx][:group]} #{node[:magento][:dir]}
    EOH
  end
end


# save node data after writing the MYSQL root password, so that a failed chef-client run that gets this far doesn't cause an unknown password to get applied to the box without being saved in the node data.
unless Chef::Config[:solo]
  ruby_block "save node data" do
    block do
      node.save
    end
    action :create
  end
end