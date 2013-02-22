require File.expand_path(File.dirname(__FILE__) + '/config_setup.rb')
require 'securerandom'

def deleteUser(user)
   begin
      #remove user from groups
      user.groups.clear
 
      #remove user's login ability
      if(user.login_profile.exists?)
         user.login_profile.delete
      end
  
      #remove user's access keys
      user.access_keys.clear

      #remove user's mfa devices
      user.mfa_devices.clear
      #remove user's signing certificates
      user.signing_certificates.clear

      #removes user from IAM
      user.delete!
   rescue
      puts "There was a problem with cleaning up after the error. This user will need to be deleted/created manually."
   end
end

if __FILE__ == $PROGRAM_NAME
   # grab user_name from args
   user_name = ARGV[0]
   gpg_path = ARGV[1]
   gpg_recipient = ARGV[2]
   group_name = 'dev'

   if (ARGV[3] == "-g") then
      group_name = ARGV[4]
   end

   unless user_name and gpg_path
      puts "Usage: upload_file.rb <USER_NAME> </PATH/TO/GPG/KEY> <GPG_RECIPIENT> [-g GROUP_NAME]"
      exit 1
   end

   # get an instance of the S3 interface using the default configuration
   iam = AWS::IAM.new
   user = iam.users[user_name]

   # check if user exists, if not create them, else return message and exit
   if(!user.exists?) then
      user = iam.users.create(user_name)
   else
      puts "This user already exists!"
      exit 1
   end


   # get the specified group
   group = iam.groups[group_name]

   # check if group exists, if not create it and notify the user that it was done for them automatically
   if(!group.exists?) then
      puts "The specified group does not exist. Aborting..."
      deleteUser(user)
      exit 1
   end

   # Add user to the group
   user.groups.add(group)

   # Create the newly created user's credentials
   key = user.access_keys.create

   #Create temporary password and enable the user's login
   temp_password = SecureRandom.hex(10)
   user.login_profile.password = temp_password

   #Redirect output
   stdout_orig = STDOUT.clone
   $stdout.reopen("#{user_name}.cred", "w")
   $stdout.sync = true

   #Print credentials
   puts "User name: " + user_name
   puts "Temporary password: " + temp_password
   puts "Key id: " + key.id
   puts "Secret key: " + key.secret

   #Restore STDOUT
   STDOUT.reopen(stdout_orig)

   #Store credentials into gpg
   system "gpg --import #{gpg_path}"
   if($?.exitstatus != 0) then
      puts "The gpg path is wrong. You will need to manually encrypt the <user>.cred file"
      exit(1)
   end

   system "gpg -r #{gpg_recipient} -e #{user_name}.cred"
   if($?.exitstatus  != 0) then
      puts "The gpg recipient is wrong. You will need to manually encrypt the <user>.cred file"
      exit(1)
   end
end
