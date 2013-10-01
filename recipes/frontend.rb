require 'time'
require 'digest/md5'

include_recipe "nginx"
include_recipe "php-fpm"


# Centos Polyfills
if platform?('centos', 'redhat')
	execute "Install libmcrypt" do
		command "rpm -Uvh --nosignature --replacepkgs http://pkgs.repoforge.org/libmcrypt/libmcrypt-2.5.7-1.2.el6.rf.#{machine}.rpm"
		action :run
	end
end

# Install required packages
node[:magento][:packages].each do |package|
	package "#{package}" do
		action :upgrade
	end
end

directory "#{node[:nginx][:dir]}/ssl" do
	owner "root"
	group "root"
	mode "0755"
	action :create
end

bash "Create SSL Certificates" do
	cwd "#{node[:nginx][:dir]}/ssl"
	code <<-EOH
	umask 022
	openssl genrsa 2048 > magento.key
	openssl req -batch -new -x509 -days 365 -key magento.key -out magento.crt
	cat magento.crt magento.key > magento.pem
	EOH
	only_if { File.zero?("#{node[:nginx][:dir]}/ssl/magento.pem") }
	action :nothing
end

cookbook_file "#{node[:nginx][:dir]}/ssl/magento.pem" do
	source "cert.pem"
	mode 0644
	owner "root"
	group "root"
	notifies :run, resources(:bash => "Create SSL Certificates"), :immediately
end

%w{backend}.each do |file|
	cookbook_file "#{node[:nginx][:dir]}/conf.d/#{file}.conf" do
	  source "nginx/#{file}.conf"
	  mode 0644
	  owner "root"
	  group "root"
	end
end

bash "Drop default site" do
	cwd "#{node[:nginx][:dir]}"
	code <<-EOH
	rm -rf conf.d/default.conf
	EOH
	notifies :reload, resources(:service => "nginx")
end

%w{default ssl}.each do |site|
	template "#{node[:nginx][:dir]}/sites-available/#{site}" do
		source "nginx-site.erb"
		owner "root"
		group "root"
		mode 0644
		variables(
		:path => "#{node[:magento][:dir]}",
		:ssl => (site == "ssl")?true:false
		)
	end
	nginx_site "#{site}" do
		notifies :reload, resources(:service => "nginx")
	end
end


unless File.exist?("#{node[:magento][:dir]}/#{node[:magento][:version]}")
  user node[:magento][:user] do
    comment "magento guy"
    home node[:magento][:dir]
    system true
  end

  directory node[:magento][:dir] do
    owner node[:magento][:user]
    group node[:nginx][:group]
    mode "0755"
    action :create
    recursive true
  end

  # Fetch magento release
  unless node[:magento][:url].empty?
    remote_file "#{Chef::Config[:file_cache_path]}/magento.tar.gz" do
      source node[:magento][:url]
      mode "0644"
    end
    execute "untar-magento" do
      cwd node[:magento][:dir]
      command "tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/magento.tar.gz"
    end
  end

  bash "Touch #{node[:magento][:dir]}/#{node[:magento][:version]} flag" do
    cwd node[:magento][:dir]
    code <<-EOH
    touch #{node[:magento][:dir]}/#{node[:magento][:version]}
    EOH
  end

  bash "Ensure correct permissions & ownership" do
    cwd node[:magento][:dir]
    code <<-EOH
    chown -R #{node[:magento][:user]}:#{node[:nginx][:group]} #{node[:magento][:dir]}
    chmod -R o+w media
    chmod -R o+w var
    EOH
  end
end

template "#{node[:magento][:dir]}/app/etc/local.xml" do
	source "local.xml.erb"
	mode "0777"
	owner node[:magento][:user]
	group node[:nginx][:group]
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
      rsync -a media/* #{node[:magento][:dir]}/media/
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

if node['magento']['newrelic'] && node['magento']['newrelic']['license']
  	include_recipe "magento::newrelic"
end

service "php5-fpm" do
    action [:enable, :restart] #starts the service if it's not running and enables it to restart at system boot time
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