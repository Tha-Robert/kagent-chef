action :csr do

  bash "sign-local-csr-key" do
    user "root"
    code <<-EOF
      set -eo pipefail 
      export PYTHON_EGG_CACHE=/tmp
      #{node["kagent"]["certs_dir"]}/csr.py
  EOF
    not_if { ::File.exists?( "#{node["kagent"]["keystore_dir"]}/node_client_truststore.jks" ) }
  end


  bash "chown-certificates" do
    user "root"
    code <<-EOH
      set -eo pipefail 
      cd #{node["kagent"]["certs_dir"]}
      chown -R root:#{node["kagent"]["certs_group"]} #{node["kagent"]["keystore_dir"]}
      chown root:#{node["kagent"]["certs_group"]} pub.pem ca_pub.pem priv.key
    EOH
  end

end


action :generate do
  homedir = "#{new_resource.homedir}"
  cb_user = "#{new_resource.cb_user}"
  cb_group = "#{new_resource.cb_group}"

  bash "generate-ssh-keypair-for-#{homedir}" do
    user cb_user
    group cb_group
    code <<-EOF
     ssh-keygen -b 2048 -f #{homedir}/.ssh/id_rsa -t rsa -q -N ''
  EOF
    not_if { ::File.exists?( "#{homedir}/.ssh/id_rsa" ) }
  end
end


action :return_publickey do
 homedir = "#{new_resource.homedir}"
 contents = ::IO.read("#{homedir}/.ssh/id_rsa.pub")

 raise if contents.empty?
 
 Chef::Log.info "Public key read is: #{contents}"
 cb = "#{new_resource.cb_name}"
 recipeName = "#{new_resource.cb_recipe}"
 cb_user = "#{new_resource.cb_user}"
 cb_group = "#{new_resource.cb_group}"

 node.default["#{cb}"]["#{recipeName}"][:public_key] = contents

  template "#{homedir}/.ssh/config" do
    source "ssh_config.erb" 
    owner cb_user
    group cb_group
    mode 0600
    cookbook "kagent"
  end
 
 kagent_param "/tmp" do
   executing_cookbook cb
   executing_recipe  recipeName
   cookbook cb
   recipe recipeName
   param "public_key"
   value  "#{contents}"
 end
end

action :get_publickey do
  homedir = "#{new_resource.homedir}"
  cb = "#{new_resource.cb_name}" 
  recipeName = "#{new_resource.cb_recipe}"
  cb_user = "#{new_resource.cb_user}"
  cb_group = "#{new_resource.cb_group}"

  key_contents = node["#{cb}"]["#{recipeName}"][:public_key]
  Chef::Log.debug "Public key read is: #{key_contents}"
  bash "add_#{cb}_#{recipeName}_public_key" do
    user "root"
    code <<-EOF
      set -e
      if [ ! -d #{homedir}/.ssh ] ; then
        mkdir #{homedir}/.ssh
      fi
      chmod 700 #{homedir}/.ssh
      echo "#{key_contents}" >> #{homedir}/.ssh/authorized_keys
      chmod 600 #{homedir}/.ssh/authorized_keys
      chown -R #{cb_user}:#{cb_group} #{homedir}/.ssh
  EOF
     not_if "grep #{key_contents} #{homedir}/.ssh/authorized_keys"
  end
end
