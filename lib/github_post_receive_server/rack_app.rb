# 
#  rack_app.rb
#  github_post_commit_server
#
#  Example Rack app for http://github.com/guides/post-receive-hooks
#  
#  Created by James Tucker on 2008-05-11.
#  Copyright 2008 James Tucker
# 

require 'rubygems'
require 'rack'
require 'json'
require 'yaml'
require 'fileutils'

module GithubPostReceiveServer
  class RackApp
    GO_AWAY_COMMENT = "Be gone, foul creature of the internet."
    THANK_YOU_COMMENT = "Thanks! You beautiful soul you."
    REPOS_FILE = "allowed_repos.yml"
    REPOS_PATH = "/mnt/redmine_apps"
    REDMINE_PATH = "/mnt/app/redmine"

    # This is what you get if you make a request that isn't a POST with a 
    # payload parameter.
    def rude_comment
      @res.write GO_AWAY_COMMENT
    end
   
    def get_allowed_repos
      unless File.exists?(REPOS_FILE)
        puts "#{REPOS_FILE} not found"
        return false
      end
      YAML::load_file(REPOS_FILE)
    end

    # Does what it says on the tin. By default, not much, it just prints the
    # received payload.
    def handle_request
      payload = @req.POST["payload"]
      
      return rude_comment if payload.nil?
      
      unless allowed_repos = get_allowed_repos
        return rude_comment
      end
      # puts "Allowed repos are #{allowed_repo_names.inspect}"  # remove me
      
      puts payload #unless $TESTING # remove me!
      payload = JSON.parse(payload)
      repo_name = payload['repository']['name']
      
      if allowed_repos.has_key?(repo_name)
        repo_path = File.join(REPOS_PATH, repo_name)
        repo_url = allowed_repos[repo_name]
        
        if File.exists?(repo_path) && File.directory?(repo_path)
          # Assuming it's a git repo
          command = "cd #{repo_path} && git pull && cd #{REDMINE_PATH} && rake redmine:fetch_changesets"
          puts command
          system(command)
        elsif !File.exists?(repo_path)
          FileUtils.mkdir_p(REPOS_PATH)
          command ="cd #{REPOS_PATH} && git clone #{repo_url} #{repo_name} && cd #{REDMINE_PATH} && rake redmine:fetch_changesets"
          puts command
          system(command)
        end

        @res.write THANK_YOU_COMMENT
      else
        @res.write GO_AWAY_COMMENT
      end
    end

    # Call is the entry point for all rack apps.
    def call(env)
      @req = Rack::Request.new(env)
      @res = Rack::Response.new
      handle_request
      @res.finish
    end
  end
end
