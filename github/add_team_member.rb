require 'rubygems'
require 'json'

if __FILE__ == $PROGRAM_NAME
   # grab user's name and the new team member's name from args
   user_name = ARGV[0]
   new_member_login = ARGV[1]

   #Check that required parameters were added
   unless user_name and new_member_login
      puts "Usage: add_team_member.rb <LOGIN_USER_NAME> <NEW_MEMBER_USER_NAME>"
      exit(1)
   end
  
   #Check if curl is installed
   `which curl`
   #If not notify user to install curl and gracefully exit
   if($? == 1) then
      puts "Curl not installed. Please install curl."
      exit(1)
   end

   #Get password for multiple curl calls
   `stty -echo`
   print "Password for #{user_name}: "
   password = $stdin.gets.chomp
   `stty echo`
   puts ""

   #Test user's password against quota check
   authentication_check = JSON.parse `curl https://api.github.com/users/#{user_name} -s -u #{user_name}:#{password}`
   if(authentication_check["message"] == "Bad credentials") then
      puts "Your username or password is invalid. Please try again."
      exit(1)
   end

   #Get teams from github api for the openshift team
   teams = JSON.parse `curl https://api.github.com/orgs/openshift/teams -s -u #{user_name}:#{password}`
  
   #Check that there are teams, and gracefully exit if not
   if(teams.size == 0) then
      puts "There are no groups available. Please add a group or check your permissions."
      exit(1)
   end

   #Print teams with option numbers
   system("clear")
   teams.each_with_index do |team, index|
      puts "#{index}" + ") " + team["name"]
   end

   #Print prompt for choosing team
   begin
      print "Please choose a group to add the user to or (Q)uit: "
      token = $stdin.gets.chomp
         if (token.casecmp('Q') == 0) then
            exit(1)
         end
      #Integer cast exception check
      group_id = Integer(token) rescue nil
   end while (!group_id || group_id >= teams.size)  

   #Get new user
   new_member = JSON.parse `curl https://api.github.com/users/#{new_member_login} -s -u #{user_name}:#{password}`
   
   #If they don't exit, notify the user and gracefully exit
   if(new_member["message"] == "Not Found") then
      puts "The specified user doesn't exist! Please try again."
      exit(1)
   end
 
   #Print user information for validation
   system ("clear")
   puts "Name: " + (new_member["name"] || "Not Available")
   puts "Company: " + (new_member["company"] || "Not Available")
   puts "Location: " + (new_member["Location"] || "Not Available")
   puts "Email: " + (new_member["email"] || "Not Available")
   puts "Profile: http://github.com/#{new_member_login}"

   #Prompt for validation of user being added
   token = ""
   while(token.casecmp('Y') != 0)
      print "The specified user's details are displayed above. Are you sure this is the person you want to add? (Y/N): "
      token = $stdin.gets.chomp
      if(token.casecmp('N') == 0) then 
         exit(0)
      end
   end
   
   #Try to add the user to the group
   add_results = JSON.parse "[" + `curl https://api.github.com/teams/#{teams[group_id]["id"]}/members/#{new_member_login} -s -X PUT -H "Content-Length: 0" -u #{user_name}:#{password}` + "]"
   
   #Check if api returned permission error
   if(add_results == "Must have admin rights to Repository.") then
      puts "You do not have permissiont to add the user to the specified group. Please check your permissions and try again."
      exit(1)
   end

   #Print that the user was successfully added
   puts "The user was successfully added to the team!"
end
