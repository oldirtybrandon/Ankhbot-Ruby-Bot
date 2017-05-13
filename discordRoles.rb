require 'socket'
include Socket::Constants
require 'concurrent'
require_relative 'db_runner.rb'

class AnkhbotClient
	# Initialize the bot on new and open the connection. Send the Pass, Nick, and Channel to join
	def initialize(name: nil, server: nil, port: nil, password: nil, channel: nil, ankhbot_directory: nil)
		@channel = channel
		@name = name
		@ankhbot_db_dir = File.join(ankhbot_directory,'Twitch','Databases')
		@script_dir = File.expand_path(File.dirname(__FILE__))
		
		@connection = TCPSocket.open(server, port)
		send("PASS #{password}")
		send("NICK #{@name}")
		send("JOIN #{@channel}")
	end
	
	# Send whatever through the socket
	def send(a)
		@connection.puts a
	end
	
	# Format message as message from the user and send it
	def say(msg)
		send "PRIVMSG #{@channel} :#{msg}"
		
	end
	
	# Matchers for received messages. Add more cases here if you'd like to implement
	# other types of automated responses or commands. For the most part you could probably just
	# do this through the Ankhbot Command interface though. 
	def basic_parse(msg)    
		case msg
		#Received PING from Server. Send PONG
		when /^PING :(.*)$/
			send("PONG #{$~[1]}")
			do_not_put = true   
		# if message from another user, parse to have user: message pretty stuff
		when /^:(.*)!(.*) PRIVMSG (.*) :(.*)$/
			puts "#{$~[1]}: #{$~[4]}"
			print("--> ")
		# This is generally the final message sent by Twitch after a successful connection. So let's tell
		# the user that we're connected
		when /^:(.*) 366 (.*)$/
			puts msg
			print("Connected... --> ")
		# If we don't match anything above, then just display the message as is
		else
			puts msg
		end
	end
	
	# Read command line input from the user
	def input_stdin!
		if input = STDIN.gets
			unless input.match(/^PRIVMSG(.*)$/)
				say input
				print("--> ")
			end
		end
	end
	
	
	# Parse messages received from server
	def output_stdout!
		msg = @connection.gets
		basic_parse(msg)
	end
	
	# Determines which users have linked their accounts and grants permission to verify. 
	def addLinked
		# Get a list of users that are newly linked
		newUsers = getLinked
		# Write the list to a text file
		open('userList.txt', 'w') newUsers.each do |userAdd|
			userAdd.puts "{userAdd}"
		end
		# Writes the number of new users to a text file
		open('userCount.txt', 'w') do |userCount|
			userCount.puts "{newUsers.count}"
		end
	end
	
	def getLinked
		# Get the current list of linked accounts
		current_db = DBRunner.new(File.join(@ankhbot_db_dir, "DiscordLinkDB.sqlite"))
		currentLinked = current_db.execute('SELECT TwitchUser FROM LinkedUser')
		
		# Get the old list of linked accounts
		old_db = DBRunner.new(File.join(@script_dir, "oldLinked.db"))
		old_db.execute('CREATE TABLE IF NOT EXISTS oldLinked(TwitchUser NVarChar(255) NOT NULL, PRIMARY KEY(TwitchUser))')
		oldLinked = old_db.execute('SELECT TwitchUser FROM oldLinked')
		
		# Compare the linked accounts and find those users who have recently linked their accounts.
		changedLinked = currentLinked - oldLinked
		
		# Write the number of new users to a text file
		userCount = changedLinked.count
			open('userCount.txt', 'w') do |countUsers|
				countUsers.puts "{userCount}"
		end
		
		# Write a list of new users to a text file
		open('userlist.txt', 'w') changedLinked.each do |linked|
			linked.puts "{linked}"
		end
		level_ups = level_ups.map do |rank|
		old_rank = old_ranks.detect { |old_rank| old_rank[0] == rank[0] }
			# If we've never seen this user before then assume the users old rank was Unranked
			old_rank = old_rank.nil? ? 'Unranked' : old_rank[1]
			{ name: rank[0], rank: rank[1], direction: check_rank_direction(old_rank, rank[1]) }
		end
		
		#Reset the old ranks to the current ranks be checked against next time
		old_db.execute('DELETE FROM old_linked')
		reset_command = "INSERT INTO old_linked ('TwitchUser') VALUES"
		values = current_linked.map {|rank| "('#{rank[0]}', '#{rank[1]}')"}
		reset_command += values.join(',')
		old_db.execute(reset_command)
		#Return the leveled up users
		level_ups
	end
	
	# Checks if the new rank is higher than the old rank
	def check_rank_direction(old_rank, new_rank)
    rank_db = DBRunner.new(File.join(@ankhbot_db_dir, "RankDB.sqlite"))
	# Get the positions of the ranks based on the points/hours required and the User Group
	ranks = rank_db.execute("SELECT Name FROM Rank order by UserGroup desc, Points asc").flatten
	new_rank_position = ranks.index(new_rank)
	old_rank_position = ranks.index(old_rank)
    # In the case either the old rank or the new rank setting was removed, return true
	if new_rank_position && old_rank_position
	  new_rank_position > old_rank_position
	else
	  true
	end
  end
  
  def run 
    
	if Settings.announcer.use_announcer
      # Run announce_ranks every 60 seconds
      task = Concurrent::TimerTask.new(execution_interval: Settings.announcer.announcer_timer, timeout_interval: 30) do
        announce_ranks
      end
	  task.execute
	end
	
	# Begin checking socket and stdin for messages from Twitch or the user
	until @connection.eof? do
      
      inou = select([@connection, STDIN], nil, nil, nil)
      next if !inou
      for s in inou[0]

        Thread.abort_on_exception = true
        stdin_thread = Thread.new do
          if s = STDIN
            input_stdin!
          end
        end
                        
        Thread.abort_on_exception = true
        stdout_thread = Thread.new do
          if s = @connection
            output_stdout!
          end
        end
      end
    end
  end

  def quit
    send "PART #{@channel}"
    send 'QUIT'
    puts "\nBye, Felicia!"
  end
end
