name             "magento"
maintainer       "Javier Perez-Griffo"
maintainer_email "javier@tapp.in"
license          "Apache 2.0"
description      "Magento app stack with three tier arquitecture"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.6.4"
recipe           "magento", "Prepares app stack for magento deployments"

%w{ debian ubuntu centos redhat fedora amazon }.each do |os|
  supports os
end

%w{ apt yum apache2 nginx mysql openssl php }.each do |cb|
  depends cb
end

depends "php-fpm", "> 0.4.1"

attribute "magento/db/host",
  :display_name => "host",
  :description => "Database host",
  :default => "localhost"

attribute "magento/db/database",
  :display_name => "database",
  :description => "Database Name",
  :default => "magento"

attribute "magento/db/username",
  :display_name => "username",
  :description => "Database Username",
  :default => "magentouser"

attribute "magento/db/sample_data",
  :display_name => "sample_data",
  :description => "Database Sample Data",
  :default => "false"

attribute "magento/db/password",
  :display_name => "password",
  :description => "Database Password"

attribute "magento/newrelic/license",
  :display_name => "license",
  :description => "New Relic License"
