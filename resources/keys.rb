actions :generate, :return_publickey, :get_publickey

attribute :homedir, :kind_of => String, :name_attribute => true, :required => true
attribute :cb_naem, :kind_of => String
attribute :cb_recipe, :kind_of => String
attribute :cb_user, :kind_of => String, :required => true
attribute :cb_group, :kind_of => String, :required => true


