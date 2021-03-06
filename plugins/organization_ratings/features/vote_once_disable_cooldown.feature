Feature: vote_once_disable_cooldown
  As a admin
  I want to disable the cooldown time when vote once is enabled
  Making it clearly that there is no cooldown when vote once is enabled

  Background:
    Given plugin "OrganizationRatings" is enabled on environment
    And I am logged in as admin
    And I go to /admin/plugins
  
  @selenium
  Scenario: disable or enable the cooldown field when vote on is checked or unchecked
    Given I check "Organization Ratings"
    And I follow "Save changes"
    And I follow "menu-dropdown"
    And I follow "Administration"
    And I follow "Plugins"
    And I follow "Configuration"
    Then the field "#organization_ratings_config_cooldown" should be enabled
    And I check "Vote once"
    Then the field "#organization_ratings_config_cooldown" should be disabled
    And I uncheck "Vote once"
    Then the field "#organization_ratings_config_cooldown" should be enabled
