include_recipe "php"
#
# Configuring NewRelic Repository
#
case node['platform']
    when "debian", "ubuntu", "redhat", "centos", "fedora", "scientific", "amazon"
        package "wget"
end

case node['platform']
    when "debian", "ubuntu"
        #trust the New Relic GPG Key
        #this step is required to tell apt that you trust the integrity of New Relic's apt repository
        gpg_key_id = "548C16BF"

        gpg_key_url = "http://download.newrelic.com/#{gpg_key_id}.gpg"

        execute "newrelic-add-gpg-key" do
            command "wget -O - #{gpg_key_url} | apt-key add -"
            notifies :run, "execute[newrelic-apt-get-update]", :immediately
            not_if "apt-key list | grep #{gpg_key_id}"
        end

        #configure the New Relic apt repository
        remote_file "/etc/apt/sources.list.d/newrelic.list" do
            source "http://download.newrelic.com/debian/newrelic.list"
            owner "root"
            group "root"
            mode 0644
            notifies :run, "execute[newrelic-apt-get-update]", :immediately
            action :create_if_missing
        end

        #update the local package list
        execute "newrelic-apt-get-update" do
            command "apt-get update"
            action :nothing
        end
    when "redhat", "centos", "fedora", "scientific", "amazon"
        #install the newrelic-repo package, which configures a new package repository for yum
        if node['kernel']['machine'] == "x86_64"
            machine = "x86_64"
        else
            machine = "i386"
        end

        remote_file "#{Chef::Config['file_cache_path'] || '/tmp'}/newrelic-repo-5-3.noarch.rpm" do
            source "http://download.newrelic.com/pub/newrelic/el5/#{machine}/newrelic-repo-5-3.noarch.rpm"
            action :create_if_missing
        end

        package "newrelic-repo" do
            source "#{Chef::Config['file_cache_path'] || '/tmp'}/newrelic-repo-5-3.noarch.rpm"
            provider Chef::Provider::Package::Rpm
            action :install
        end
end

#install/update latest php agent
package "newrelic-php5" do
    action :upgrade
    notifies :run, "execute[newrelic-install]", :immediately
end

#run newrelic-install
execute "newrelic-install" do
    command "newrelic-install install"
    action :nothing
    notifies :restart, "service[nginx]", :delayed
end

service "newrelic-daemon" do
    supports :status => true, :start => true, :stop => true, :restart => true
end

#ensure that the daemon isn't currently running
service "newrelic-daemon" do
    action [:disable, :stop] #stops the service if it's running and disables it from starting at system boot time
end

#ensure that the file /etc/newrelic/newrelic.cfg does not exist if it does, move it aside (or remove it)
execute "newrelic-backup-cfg" do
    command "mv /etc/newrelic/newrelic.cfg /etc/newrelic/newrelic.cfg.external"
    only_if do File.exists?("/etc/newrelic/newrelic.cfg") end
end

#ensure that the file /etc/newrelic/upgrade_please.key does not exist if it does, move it aside (or remove it)
execute "newrelic-backup-key" do
    command "mv /etc/newrelic/upgrade_please.key /etc/newrelic/upgrade_please.key.external"
    only_if do File.exists?("/etc/newrelic/upgrade_please.key") end
end

#configure New Relic INI file and set the daemon related options (documented at /usr/lib/newrelic-php5/scripts/newrelic.ini.template)
#and restart the web server in order to pick up the new settings
template "#{node['php']['ext_conf_dir']}/newrelic.ini" do
    source "newrelic.ini.php.erb"
    owner "root"
    group "root"
    mode "0644"
    variables(
        :enabled => node['magento']['newrelic']['enabled'],
        :license => node['magento']['newrelic']['license'],
        :logfile => node['magento']['newrelic']['logfile'],
        :loglevel => node['magento']['newrelic']['loglevel'],
        :appname => node['magento']['newrelic']['appname'],
        :daemon_logfile => node['magento']['newrelic']['daemon']['logfile'],
        :daemon_loglevel => node['magento']['newrelic']['daemon']['loglevel'],
        :daemon_port => node['magento']['newrelic']['daemon']['port'],
        :daemon_max_threads => node['magento']['newrelic']['daemon']['max_threads'],
        :daemon_ssl => node['magento']['newrelic']['daemon']['ssl'],
        :daemon_ssl_ca_path => node['magento']['newrelic']['daemon']['ssl_ca_path'],
        :daemon_ssl_ca_bundle => node['magento']['newrelic']['daemon']['ssl_ca_bundle'],
        :daemon_proxy => node['magento']['newrelic']['daemon']['proxy'],
        :daemon_pidfile => node['magento']['newrelic']['daemon']['pidfile'],
        :daemon_location => node['magento']['newrelic']['daemon']['location'],
        :daemon_collector_host => node['magento']['newrelic']['daemon']['collector_host'],
        :daemon_dont_launch => node['magento']['newrelic']['daemon']['dont_launch'],
        :capture_params => node['magento']['newrelic']['capture_params'],
        :ignored_params => node['magento']['newrelic']['ignored_params'],
        :error_collector_enable => node['magento']['newrelic']['error_collector']['enable'],
        :error_collector_record_database_errors => node['magento']['newrelic']['error_collector']['record_database_errors'],
        :error_collector_prioritize_api_errors => node['magento']['newrelic']['error_collector']['prioritize_api_errors'],
        :browser_monitoring_auto_instrument => node['magento']['newrelic']['browser_monitoring']['auto_instrument'],
        :transaction_tracer_enable => node['magento']['newrelic']['transaction_tracer']['enable'],
        :transaction_tracer_threshold => node['magento']['newrelic']['transaction_tracer']['threshold'],
        :transaction_tracer_detail => node['magento']['newrelic']['transaction_tracer']['detail'],
        :transaction_tracer_slow_sql => node['magento']['newrelic']['transaction_tracer']['slow_sql'],
        :transaction_tracer_stack_trace_threshold => node['magento']['newrelic']['transaction_tracer']['stack_trace_threshold'],
        :transaction_tracer_explain_threshold => node['magento']['newrelic']['transaction_tracer']['explain_threshold'],
        :transaction_tracer_record_sql => node['magento']['newrelic']['transaction_tracer']['record_sql'],
        :transaction_tracer_custom => node['magento']['newrelic']['transaction_tracer']['custom'],
        :framework => node['magento']['newrelic']['framework'],
        :webtransaction_name_remove_trailing_path => node['magento']['newrelic']['webtransaction']['name']['remove_trailing_path'],
        :webtransaction_name_functions => node['magento']['newrelic']['webtransaction']['name']['functions'],
        :webtransaction_name_files => node['magento']['newrelic']['webtransaction']['name']['files']
    )
    action :create
    notifies :restart, "service[nginx]", :delayed
end

#configure proxy daemon settings
template "/etc/newrelic/newrelic.cfg" do
    source "newrelic.cfg.erb"
    owner "root"
    group "root"
    mode "0644"
    variables(
        :daemon_pidfile => node['magento']['newrelic']['daemon']['pidfile'],
        :daemon_logfile => node['magento']['newrelic']['daemon']['logfile'],
        :daemon_loglevel => node['magento']['newrelic']['daemon']['loglevel'],
        :daemon_port => node['magento']['newrelic']['daemon']['port'],
        :daemon_ssl => node['magento']['newrelic']['daemon']['ssl'],
        :daemon_proxy => node['magento']['newrelic']['daemon']['proxy'],
        :daemon_ssl_ca_path => node['magento']['newrelic']['daemon']['ssl_ca_path'],
        :daemon_ssl_ca_bundle => node['magento']['newrelic']['daemon']['ssl_ca_bundle'],
        :daemon_max_threads => node['magento']['newrelic']['daemon']['max_threads'],
        :daemon_collector_host => node['magento']['newrelic']['daemon']['collector_host']
    )
    action :create
    notifies :restart, "service[newrelic-daemon]", :immediately
    notifies :restart, "service[nginx]", :delayed
end

service "newrelic-daemon" do
    action [:enable, :start] #starts the service if it's not running and enables it to start at system boot time
end