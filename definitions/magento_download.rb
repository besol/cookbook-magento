define :magento_download do
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
end