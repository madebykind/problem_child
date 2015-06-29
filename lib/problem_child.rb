require 'octokit'
require 'sinatra'
require 'sinatra_auth_github'
require 'dotenv'
require 'json'
require 'redis'
require 'rack/session/moneta'
require 'active_support'
require 'active_support/core_ext/string'
require "problem_child/version"
require "problem_child/helpers"

module ProblemChild

  def self.root
    File.expand_path "./problem_child", File.dirname(__FILE__)
  end

  def self.views_dir
    @views_dir ||= File.expand_path "views", ProblemChild.root
  end

  def self.views_dir=(dir)
    @views_dir = dir
  end

  class App < Sinatra::Base

    include ProblemChild::Helpers

    set :github_options, {
      :scopes => "repo,read:org"
    }

    use Rack::Session::Moneta, store: :Redis, url: ENV["REDIS_URL"]

    configure :production do
      require 'rack-ssl-enforcer'
      use Rack::SslEnforcer
    end

    ENV['WARDEN_GITHUB_VERIFIER_SECRET'] ||= SecureRandom.hex
    register Sinatra::Auth::Github

    set :views, Proc.new { ProblemChild.views_dir }
    set :root,  Proc.new { ProblemChild.root }
    set :public_folder, Proc.new { File.expand_path "public", ProblemChild.root }

    get "/" do
      if session[:form_data]
        issue = uploads ? create_pull_request : create_issue
        session[:form_data] = nil
        access = repo_access?
      else
        issue = nil
        access = false
        auth!
      end
      halt erb :form, :layout => :layout, :locals => { :repo => repo, :anonymous => anonymous_submissions?, :issue => issue, :access => access }
    end

    post "/" do
      cache_form_data
      auth! unless anonymous_submissions?
      halt redirect "/"
    end
  end
end

Dotenv.load unless ProblemChild::App.production?
