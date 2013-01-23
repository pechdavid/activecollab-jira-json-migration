Activecollab to Jira JSON Migration
================================

Migrate from Active Collab (2.3.x+) to Jira via JSON format!

Simple migration script that enables you: 

* migrate all project issues
* comments to issues
* users involved
* attachments (via dirty script)
* migrate milestones (as versions in Jira)

Attachments with dirty script
================================

# upload serve.php to active collab public
# enable through .htaccess
# make migration
# don't forget to remove file after migration

Known Issues
================================

* Removed users are migrated only as their ID
* Problem migrating multiple attachments with the same name in the issue
