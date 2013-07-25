#!/usr/bin/env ruby

require "net/http"
require "uri"
require "json"
require "time"

if (ARGV.size != 4)
	$stderr.puts "Usage: ./active-collab-jira-json.rb AC_URL AC_USER_API_KEY AC_PROJECT_ID JIRA_PROJECT_ID > export.json"
	$stderr.puts "Example: ./active-collab-jira-json.rb http://ac.mydomain.name 20-123213123123123 12 JIRAPROJ > export.json"
	$stderr.puts "And import it to Jira!"
	exit(0)
end
	


URL = ARGV[0]
KEY = ARGV[1]
PROJECT_ID = ARGV[2].to_i
TARGET_PROJECT = ARGV[3]
BASE_URL = "%s/api.php\?token\=%s\&format\=json\&path_info\=" % [URL, KEY]

$EMAILS = {}
$MILESTONES = {}

def json_url(append)
	uri = URI.parse(BASE_URL + append)
	response = Net::HTTP.get_response(uri)
	body = response.body
	if body == "null" then
		{}
	else
		JSON.parse(body)
	end
end


def get_milestone(milestone_id)
	milestone_id = milestone_id.to_i
	if not $MILESTONES[milestone_id]
		begin
			raw = json_url("projects/" + PROJECT_ID.to_s + "/milestones/" + milestone_id.to_s)
		rescue
			$stderr.puts "Milestone not found: " + milestone_id.to_s
			raw = {"name" => nil}
		end
		 
		$MILESTONES[milestone_id]  = raw["name"]
	end

	$MILESTONES[milestone_id]
end

def get_email(user_id)
	user_id = user_id.to_i
	if not $EMAILS[user_id]
		begin
			raw = json_url("people/1/users/" + user_id.to_s)
		rescue
			$stderr.puts "User not found: " + user_id.to_s
			raw = {"email" => nil}
		end
		 
		$EMAILS[user_id]  = raw["email"]
	end

	$EMAILS[user_id]
end

def timestamp(str)
	if str.nil?
		nil
	else
		Time.parse(str).to_i * 1000
	end
end

def body(str)
	if str.nil?
		nil
	else
		str.gsub("<p>", "").gsub("</p>", "\n\n")
	end
end

def iterate_tickets(append)
	raw_list = json_url("projects/" + PROJECT_ID.to_s + "/tickets" + append)

	out_issues = []

	raw_list.collect do |ticket_thumb|
		raw = json_url("projects/" + PROJECT_ID.to_s + "/tickets/" + ticket_thumb["ticket_id"].to_s)

		$stderr.puts "#" + ticket_thumb["ticket_id"].to_s + ": " + raw["name"]

		attachments = raw["attachments"]

		raw["comments"].each do |comment|
			attachments = attachments.concat(comment["attachments"])
		end

		#p raw

		assignee = nil
		if raw["assignees"]
			filtered = raw["assignees"].delete_if {|e| !e["is_owner"]}
			unless filtered.empty?
				assignee = get_email(filtered.first["user_id"])
			end
		end

		priority = case raw["priority"]
		when -2
			"Trivial"
		when -1
			"Minor"
		when 1
			"Critical"
		when 2
			"Blocker"
		else
			"Major"
		end

		status = nil
		resolution = nil

		case append
		when "/archive"
			status = "Closed"
			resolution = "Fixed"
		else
			status = "Open"
			resolution = nil
		end

		fixedVersions = []
		unless raw["milestone_id"].nil?
			fixedVersions = [ get_milestone(raw["milestone_id"]) ]
		end

		#$stderr.puts attachments

		{
			"summary" =>  raw["name"],
			"description" => body(raw["body"]),
			"issueType" => "Story",
			"status" => status,
			"resolution" => resolution,
			"priority" => priority,
			"created" => timestamp(raw["created_on"]),
			"updated" => timestamp(raw["updated"]),
			"duedate" => timestamp(raw["due_on"]),
			"resolutionDate" => timestamp(raw["completed_on"]),
			"fixedVersions" => fixedVersions.compact,
			"externalId" => ticket_thumb["ticket_id"].to_s,
			"comments" => raw["comments"].collect do |cm|
				{
				 "body" => body(cm["body"]),
				 "created" => timestamp(cm["created_on"]),
				 "author" => get_email(cm["created_by_id"])
				}
			end,
			"attachments" => attachments.collect do |at|
				{
					"attacher" => get_email(at["created_by_id"]),
					"name" => at["name"],
					"created" => timestamp(at["created_on"]),
					"uri" => at["permalink"].sub("attachments/", "serve.php?file=")
				}
			end,
			"assignee" => assignee,
			"reporter" => get_email(raw["created_by_id"])
		}
	end
end

def export_project()
	{
		"projects" =>
			[
				{
					"issues" => iterate_tickets("").concat(iterate_tickets("/archive")),
					"key" => TARGET_PROJECT,
					"versions" =>
						$MILESTONES.reject {|key, value| value.nil? }.collect do |k, v|
							{
							"name" => v,
							}
						end
				}
			],
		"users" =>
			$EMAILS.reject {|key, value| value.nil? }.collect do |k, v|
				{
				 "name" => v,
				 "email" => v,
				 "groups" => ["activecollab-unused-import"]
				}
			end
	}.to_json
end


puts export_project()
