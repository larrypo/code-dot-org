require 'test_helper'

module Pd::Application
  class Teacher1819ApplicationTest < ActiveSupport::TestCase
    include Pd::Teacher1819ApplicationConstants
    include ApplicationConstants
    include RegionalPartnerTeacherconMapping

    freeze_time

    test 'application guid is generated on create' do
      teacher_application = build :pd_teacher1819_application
      assert_nil teacher_application.application_guid

      teacher_application.save!
      assert_not_nil teacher_application.application_guid
    end

    test 'existing guid is preserved' do
      guid = SecureRandom.uuid
      teacher_application = create :pd_teacher1819_application, application_guid: guid
      assert_equal guid, teacher_application.application_guid

      # save again
      teacher_application.save!
      assert_equal guid, teacher_application.application_guid
    end

    test 'principal_approval_url' do
      teacher_application = build :pd_teacher1819_application
      assert_nil teacher_application.principal_approval_url

      # save to generate guid and therefore principal approval url
      teacher_application.save!
      assert teacher_application.principal_approval_url
    end

    test 'principal_greeting' do
      hash_with_principal_title = build :pd_teacher1819_application_hash
      hash_without_principal_title = build :pd_teacher1819_application_hash, principal_title: nil

      application_with_principal_title = build :pd_teacher1819_application, form_data_hash: hash_with_principal_title
      application_without_principal_title = build :pd_teacher1819_application, form_data_hash: hash_without_principal_title

      assert_equal 'Dr. Dumbledore', application_with_principal_title.principal_greeting
      assert_equal 'Albus Dumbledore', application_without_principal_title.principal_greeting
    end

    test 'meets criteria says an application meets critera when all YES_NO fields are marked yes' do
      teacher_application = build :pd_teacher1819_application, course: 'csp',
        response_scores: CRITERIA_SCORE_QUESTIONS_CSP.map {|x| [x, 'Yes']}.to_h.to_json
      assert_equal 'Yes', teacher_application.meets_criteria

      teacher_application = build :pd_teacher1819_application, course: 'csd',
        response_scores: CRITERIA_SCORE_QUESTIONS_CSD.map {|x| [x, 'Yes']}.to_h.to_json
      assert_equal 'Yes', teacher_application.meets_criteria
    end

    test 'meets criteria says an application does not meet criteria when any YES_NO fields are marked NO' do
      teacher_application = build :pd_teacher1819_application, response_scores: {
        committed: 'No'
      }.to_json
      assert_equal 'No', teacher_application.meets_criteria
    end

    test 'meets criteria returns incomplete when an application does not have YES on all YES_NO fields but has no NOs' do
      teacher_application = build :pd_teacher1819_application, response_scores: {
        committed: 'Yes'
      }.to_json
      assert_equal 'Reviewing incomplete', teacher_application.meets_criteria
    end

    test 'total score calculates the sum of all response scores' do
      teacher_application = build :pd_teacher1819_application, response_scores: {
        free_lunch_percent: '5',
        underrepresented_minority_percent: '5',
        able_to_attend_single: TEXT_FIELDS[:able_to_attend_single],
        csp_which_grades: nil
      }.to_json

      assert_equal 10, teacher_application.total_score
    end

    test 'autoscore does not override existing scores' do
      application_hash = build :pd_teacher1819_application_hash, {
        committed: YES,
        able_to_attend_single: TEXT_FIELDS[:able_to_attend_single],
        csp_which_grades: ['12'],
        csp_course_hours_per_year: Pd::Application::ApplicationBase::COMMON_OPTIONS[:course_hours_per_year].first,
        previous_yearlong_cdo_pd: ['CS Discoveries'],
        csp_how_offer: Pd::Application::Teacher1819Application.options[:csp_how_offer].last,
        taught_in_past: ['CS in Algebra']
      }

      application = create(:pd_teacher1819_application, course: 'csp', form_data_hash: application_hash, regional_partner: (create :regional_partner))
      application.auto_score!

      assert_equal(
        {
          regional_partner_name: YES,
          committed: YES,
          able_to_attend_single: YES,
          csp_which_grades: YES,
          csp_course_hours_per_year: YES,
          previous_yearlong_cdo_pd: YES,
          csp_how_offer: 2,
          taught_in_past: 2
        }, application.response_scores_hash
      )

      application.update_form_data_hash(
        {
          principal_approval: YES,
          schedule_confirmed: YES,
          diversity_recruitment: YES,
          free_lunch_percent: '50.1%',
          underrepresented_minority_percent: '50.1%',
          wont_replace_existing_course: Pd::Application::PrincipalApproval1819Application.options[:replace_course].second,
        }
      )

      application.update(response_scores: application.response_scores_hash.merge({regional_partner_name: NO}).to_json)

      application.auto_score!
      assert_equal(
        {
          regional_partner_name: NO,
          committed: YES,
          able_to_attend_single: YES,
          principal_approval: YES,
          schedule_confirmed: YES,
          diversity_recruitment: YES,
          free_lunch_percent: 5,
          underrepresented_minority_percent: 5,
          wont_replace_existing_course: 5,
          csp_which_grades: YES,
          csp_course_hours_per_year: YES,
          previous_yearlong_cdo_pd: YES,
          csp_how_offer: 2,
          taught_in_past: 2
        }, application.response_scores_hash
      )
    end

    test 'autoscore for a CSP application where they should get YES/Points for everything' do
      application_hash = build :pd_teacher1819_application_hash, {
        committed: YES,
        able_to_attend_single: TEXT_FIELDS[:able_to_attend_single],
        principal_approval: YES,
        schedule_confirmed: YES,
        diversity_recruitment: YES,
        free_lunch_percent: '50.1%',
        underrepresented_minority_percent: '50.1%',
        wont_replace_existing_course: Pd::Application::PrincipalApproval1819Application.options[:replace_course].second,
        csp_which_grades: ['12'],
        csp_course_hours_per_year: Pd::Application::ApplicationBase::COMMON_OPTIONS[:course_hours_per_year].first,
        previous_yearlong_cdo_pd: ['CS Discoveries'],
        csp_how_offer: Pd::Application::Teacher1819Application.options[:csp_how_offer].last,
        taught_in_past: ['CS in Algebra']
      }

      application = create :pd_teacher1819_application, course: 'csp', form_data_hash: application_hash
      application.update(regional_partner: (create :regional_partner))
      application.auto_score!

      assert_equal(
        {
          regional_partner_name: YES,
          committed: YES,
          able_to_attend_single: YES,
          principal_approval: YES,
          schedule_confirmed: YES,
          diversity_recruitment: YES,
          free_lunch_percent: 5,
          underrepresented_minority_percent: 5,
          wont_replace_existing_course: 5,
          csp_which_grades: YES,
          csp_course_hours_per_year: YES,
          previous_yearlong_cdo_pd: YES,
          csp_how_offer: 2,
          taught_in_past: 2
        }, application.response_scores_hash
      )
    end

    test 'autoscore for a CSP application where they should get NO/No points for everything' do
      application_hash = build :pd_teacher1819_application_hash, {
        committed: Pd::Application::Teacher1819Application.options[:committed].last,
        able_to_attend_single: TEXT_FIELDS[:no_explain],
        principal_approval: YES,
        schedule_confirmed: NO,
        diversity_recruitment: NO,
        free_lunch_percent: '49.9%',
        underrepresented_minority_percent: '49.9%',
        wont_replace_existing_course: YES,
        csp_which_grades: ['12'],
        csp_course_hours_per_year: Pd::Application::ApplicationBase::COMMON_OPTIONS[:course_hours_per_year].last,
        previous_yearlong_cdo_pd: ['CS Principles'],
        csp_how_offer: Pd::Application::Teacher1819Application.options[:csp_how_offer].first,
        taught_in_past: ['AP CS A']
      }

      application = create :pd_teacher1819_application, course: 'csp', form_data_hash: application_hash, regional_partner: nil
      application.auto_score!

      assert_equal(
        {
          regional_partner_name: NO,
          committed: NO,
          able_to_attend_single: NO,
          principal_approval: YES, # Keep this as yes to test additional fields
          schedule_confirmed: NO,
          diversity_recruitment: NO,
          free_lunch_percent: 0,
          underrepresented_minority_percent: 0,
          wont_replace_existing_course: nil,
          csp_which_grades: YES, # Not possible to select responses for which this would be No
          csp_course_hours_per_year: NO,
          previous_yearlong_cdo_pd: NO,
          csp_how_offer: 0,
          taught_in_past: 0
        }, application.response_scores_hash
      )
    end

    test 'autoscore for a CSD application where they should get YES/Points for everything' do
      application_hash = build(:pd_teacher1819_application_hash, :csd,
        committed: YES,
        able_to_attend_single: TEXT_FIELDS[:able_to_attend_single],
        principal_approval: YES,
        schedule_confirmed: YES,
        diversity_recruitment: YES,
        free_lunch_percent: '50.1%',
        underrepresented_minority_percent: '50.1%',
        wont_replace_existing_course: Pd::Application::PrincipalApproval1819Application.options[:replace_course].second,
        csd_which_grades: ['10', '11'],
        csd_course_hours_per_year: Pd::Application::ApplicationBase::COMMON_OPTIONS[:course_hours_per_year].first,
        previous_yearlong_cdo_pd: ['CS in Science'],
        taught_in_past: Pd::Application::Teacher1819Application.options[:taught_in_past].last
      )

      application = create :pd_teacher1819_application, course: 'csd', form_data_hash: application_hash
      application.update(regional_partner: (create :regional_partner))
      application.auto_score!

      assert_equal(
        {
          regional_partner_name: YES,
          committed: YES,
          able_to_attend_single: YES,
          principal_approval: YES,
          schedule_confirmed: YES,
          diversity_recruitment: YES,
          free_lunch_percent: 5,
          underrepresented_minority_percent: 5,
          wont_replace_existing_course: 5,
          csd_which_grades: YES,
          csd_course_hours_per_year: YES,
          previous_yearlong_cdo_pd: YES,
          taught_in_past: 2
        }, application.response_scores_hash
      )
    end

    test 'autoscore for a CSD application where they should get NO/No points for everything' do
      application_hash = build(:pd_teacher1819_application_hash, :csd,
        committed: Pd::Application::Teacher1819Application.options[:committed].last,
        able_to_attend_single: TEXT_FIELDS[:no_explain],
        principal_approval: YES,
        schedule_confirmed: NO,
        diversity_recruitment: NO,
        free_lunch_percent: '49.9%',
        underrepresented_minority_percent: '49.9%',
        wont_replace_existing_course: YES,
        csd_which_grades: ['12'],
        csd_course_hours_per_year: Pd::Application::ApplicationBase::COMMON_OPTIONS[:course_hours_per_year].last,
        previous_yearlong_cdo_pd: ['Exploring Computer Science'],
        taught_in_past: ['Exploring Computer Science']
      )

      application = create :pd_teacher1819_application, course: 'csd', form_data_hash: application_hash, regional_partner: nil
      application.auto_score!

      assert_equal(
        {
          regional_partner_name: NO,
          committed: NO,
          able_to_attend_single: NO,
          principal_approval: YES, # Keep this as yes to test additional fields
          schedule_confirmed: NO,
          diversity_recruitment: NO,
          free_lunch_percent: 0,
          underrepresented_minority_percent: 0,
          wont_replace_existing_course: nil,
          csd_which_grades: NO,
          csd_course_hours_per_year: NO,
          previous_yearlong_cdo_pd: NO,
          taught_in_past: 0
        }, application.response_scores_hash
      )
    end

    test 'autoscore for able_to_attend_multiple' do
      application_hash = build :pd_teacher1819_application_hash, :with_multiple_workshops, :csd
      application = create :pd_teacher1819_application, form_data: application_hash.to_json, regional_partner: nil

      application.auto_score!

      assert_equal(YES, application.response_scores_hash[:able_to_attend_multiple])
    end

    test 'autoscore for ambiguous responses to able_to_attend_multiple' do
      application_hash = build(:pd_teacher1819_application_hash, :csd, :with_multiple_workshops,
        able_to_attend_multiple: [
          "December 11-15, 2017 in Indiana, USA",
          TEXT_FIELDS[:no_explain]
        ]
      )

      application = create :pd_teacher1819_application, form_data: application_hash.to_json, regional_partner: nil
      application.auto_score!

      assert_nil application.response_scores_hash[:able_to_attend_multiple]
    end

    test 'autoscore for not able_to_attend_multiple' do
      application_hash = build(:pd_teacher1819_application_hash, :csd, :with_multiple_workshops,
        program: Pd::Application::Teacher1819Application::PROGRAM_OPTIONS.first,
        able_to_attend_multiple: [TEXT_FIELDS[:no_explain]]
      )

      application = create :pd_teacher1819_application, form_data: application_hash.to_json, regional_partner: nil
      application.auto_score!

      assert_equal(NO, application.response_scores_hash[:able_to_attend_multiple])
    end

    test 'application meets criteria if able to attend single workshop' do
      application_hash = build(:pd_teacher1819_application_hash,
        principal_approval: YES,
        schedule_confirmed: YES,
        diversity_recruitment: YES
      )
      application = create :pd_teacher1819_application, form_data: application_hash.to_json, regional_partner: (create :regional_partner)
      application.auto_score!

      assert_equal(YES, application.meets_criteria)
    end

    test 'application meets criteria if able to attend multiple workshops' do
      application_hash = build(:pd_teacher1819_application_hash, :with_multiple_workshops,
        principal_approval: YES,
        schedule_confirmed: YES,
        diversity_recruitment: YES
      )
      application = create :pd_teacher1819_application, form_data: application_hash.to_json, regional_partner: (create :regional_partner)
      application.auto_score!

      assert_equal(YES, application.meets_criteria)
    end

    test 'application does not meet criteria if unable to attend single workshop' do
      application_hash = build(:pd_teacher1819_application_hash,
        able_to_attend_single: [TEXT_FIELDS[:no_explain]],
        principal_approval: YES,
        schedule_confirmed: YES,
        diversity_recruitment: YES
      )
      application = create :pd_teacher1819_application, form_data: application_hash.to_json, regional_partner: (create :regional_partner)
      application.auto_score!

      assert_equal(NO, application.meets_criteria)
    end

    test 'application does not meet criteria if unable to attend multiple workshops' do
      application_hash = build(:pd_teacher1819_application_hash, :with_multiple_workshops,
        able_to_attend_multiple: [TEXT_FIELDS[:no_explain]],
        principal_approval: YES,
        schedule_confirmed: YES,
        diversity_recruitment: YES
      )
      application = create :pd_teacher1819_application, form_data: application_hash.to_json, regional_partner: (create :regional_partner)
      application.auto_score!
      assert_equal(NO, application.meets_criteria)
    end

    test 'accepted_at updates times' do
      today = Date.today.to_time
      tomorrow = Date.tomorrow.to_time
      application = create :pd_teacher1819_application
      assert_nil application.accepted_at

      Timecop.freeze(today) do
        application.update!(status: 'accepted')
        assert_equal today, application.accepted_at.to_time

        application.update!(status: 'declined')
        assert_nil application.accepted_at
      end

      Timecop.freeze(tomorrow) do
        application.update!(status: 'accepted')
        assert_equal tomorrow, application.accepted_at.to_time
      end
    end

    test 'school_info_attr for specific school' do
      school = create :school
      form_data_hash = build :pd_teacher1819_application_hash, school: school
      application = create :pd_teacher1819_application, form_data_hash: form_data_hash
      assert_equal({school_id: school.id}, application.school_info_attr)
    end

    test 'school_info_attr for custom school' do
      application = create :pd_teacher1819_application, form_data_hash: (
      build :pd_teacher1819_application_hash,
        :with_custom_school,
        school_name: 'Code.org',
        school_address: '1501 4th Ave',
        school_city: 'Seattle',
        school_state: 'Washington',
        school_zip_code: '98101',
        school_type: 'Public school'
      )
      assert_equal(
        {
          country: 'US',
          school_type: 'public',
          state: 'Washington',
          zip: '98101',
          school_name: 'Code.org',
          full_address: '1501 4th Ave',
          validation_type: SchoolInfo::VALIDATION_NONE
        },
        application.school_info_attr
      )
    end

    test 'update_user_school_info with specific school overwrites user school info' do
      user = create :teacher, school_info: create(:school_info)
      application_school_info = create :school_info
      application = create :pd_teacher1819_application, user: user, form_data_hash: (
        build :pd_teacher1819_application_hash, school: application_school_info.school
      )

      application.update_user_school_info!
      assert_equal application_school_info, user.school_info
    end

    test 'update_user_school_info with custom school does nothing when the user already a specific school' do
      original_school_info = create :school_info
      user = create :teacher, school_info: original_school_info
      application = create :pd_teacher1819_application, user: user, form_data_hash: (
        build :pd_teacher1819_application_hash, :with_custom_school
      )

      application.update_user_school_info!
      assert_equal original_school_info, user.school_info
    end

    test 'update_user_school_info with custom school updates user info when user does not have a specific school' do
      original_school_info = create :school_info_us_other
      user = create :teacher, school_info: original_school_info
      application = create :pd_teacher1819_application, user: user, form_data_hash: (
        build :pd_teacher1819_application_hash, :with_custom_school
      )

      application.update_user_school_info!
      refute_equal original_school_info.id, user.school_info_id
      assert_not_nil user.school_info_id
    end

    test 'get_first_selected_workshop single local workshop' do
      workshop = create :pd_workshop
      application = create :pd_teacher1819_application, form_data_hash: (
        build :pd_teacher1819_application_hash, regional_partner_workshop_ids: [workshop.id]
      )

      assert_equal workshop, application.get_first_selected_workshop
    end

    test 'get_first_selected_workshop multiple local workshops' do
      workshops = (1..3).map {|i| create :pd_workshop, num_sessions: 2, sessions_from: Date.today + i, location_address: %w(tba TBA tba)[i - 1]}

      application = create :pd_teacher1819_application, form_data_hash: (
        build(:pd_teacher1819_application_hash, :with_multiple_workshops,
          regional_partner_workshop_ids: workshops.map(&:id),
          able_to_attend_multiple: (
            # Select all but the first. Expect the first selected to be returned below
            workshops[1..-1].map do |workshop|
              "#{workshop.friendly_date_range} in #{workshop.location_address} hosted by Code.org"
            end
          )
        )
      )
      assert_equal workshops[1], application.get_first_selected_workshop
    end

    test 'get_first_selected_workshop multiple local workshops no selection returns first' do
      workshops = (1..2).map {|i| create :pd_workshop, num_sessions: 2, sessions_from: Date.today + i}

      application = create :pd_teacher1819_application, form_data_hash: (
        build(:pd_teacher1819_application_hash, :with_multiple_workshops,
          regional_partner_workshop_ids: workshops.map(&:id),
          able_to_attend_multiple: []
        )
      )
      assert_equal workshops.first, application.get_first_selected_workshop
    end

    test 'get_first_selected_workshop with no workshops returns nil' do
      application = create :pd_teacher1819_application, form_data_hash: (
      build(:pd_teacher1819_application_hash, :with_multiple_workshops,
        regional_partner_workshop_ids: []
        )
      )
      assert_nil application.get_first_selected_workshop
    end

    test 'get_first_selected_workshop returns nil for teachercon even with local workshops' do
      workshop = create :pd_workshop
      application = create :pd_teacher1819_application, form_data_hash: (
        build :pd_teacher1819_application_hash, teachercon: TC_PHOENIX, regional_partner_workshop_ids: [workshop.id]
      )

      assert_nil application.get_first_selected_workshop
    end

    test 'get_first_selected_workshop ignores single deleted workshops' do
      workshop = create :pd_workshop
      application = create :pd_teacher1819_application, form_data_hash: (
        build :pd_teacher1819_application_hash, regional_partner_workshop_ids: [workshop.id]
      )

      workshop.destroy
      assert_nil application.get_first_selected_workshop
    end

    test 'get_first_selected_workshop ignores deleted workshop from multiple list' do
      workshops = (1..2).map {|i| create :pd_workshop, num_sessions: 2, sessions_from: Date.today + i}

      application = create :pd_teacher1819_application, form_data_hash: (
        build(:pd_teacher1819_application_hash, :with_multiple_workshops,
          regional_partner_workshop_ids: workshops.map(&:id),
          able_to_attend_multiple: []
        )
      )

      workshops[0].destroy
      assert_equal workshops[1], application.get_first_selected_workshop

      workshops[1].destroy
      assert_nil application.get_first_selected_workshop
    end

    test 'get_first_selected_workshop picks correct workshop even when multiple are on the same day' do
      workshop_1 = create :pd_workshop, num_sessions: 2, sessions_from: Date.today + 2
      workshop_2 = create :pd_workshop, num_sessions: 2, sessions_from: Date.today + 2
      workshop_1.update_column(:location_address, 'Location 1')
      workshop_2.update_column(:location_address, 'Location 2')

      application = create :pd_teacher1819_application, form_data_hash: (
        build(:pd_teacher1819_application_hash, :with_multiple_workshops,
          regional_partner_workshop_ids: [workshop_1.id, workshop_2.id],
          able_to_attend_multiple: ["#{workshop_2.friendly_date_range} in Location 2 hosted by Code.org"]
        )
      )

      assert_equal workshop_2, application.get_first_selected_workshop

      application_2 = create :pd_teacher1819_application, form_data_hash: (
        build(:pd_teacher1819_application_hash, :with_multiple_workshops,
          regional_partner_workshop_ids: [workshop_1.id, workshop_2.id],
          able_to_attend_multiple: ["#{workshop_2.friendly_date_range} in Location 1 hosted by Code.org"]
        )
      )

      assert_equal workshop_1, application_2.get_first_selected_workshop
    end

    test 'can_see_locked_status?' do
      teacher = create :teacher
      g1_program_manager = create :program_manager, regional_partner: create(:regional_partner, group: 1)
      g3_program_manager = create :program_manager, regional_partner: create(:regional_partner, group: 3)
      workshop_admin = create :workshop_admin

      refute Teacher1819Application.can_see_locked_status?(teacher)
      refute Teacher1819Application.can_see_locked_status?(g1_program_manager)

      assert Teacher1819Application.can_see_locked_status?(g3_program_manager)
      assert Teacher1819Application.can_see_locked_status?(workshop_admin)
    end

    test 'locked status appears in csv only when the supplied user can_see_locked_status' do
      application = create :pd_teacher1819_application
      mock_user = mock

      Teacher1819Application.stubs(:can_see_locked_status?).returns(false)
      header_without_locked = Teacher1819Application.csv_header('csf', mock_user)
      refute header_without_locked.include? 'Locked'
      row_without_locked = application.to_csv_row(mock_user)
      assert_equal CSV.parse(header_without_locked).length, CSV.parse(row_without_locked).length,
        "Expected header and row to have the same number of columns, excluding Locked"

      Teacher1819Application.stubs(:can_see_locked_status?).returns(true)
      header_with_locked = Teacher1819Application.csv_header('csf', mock_user)
      assert header_with_locked.include? 'Locked'
      row_with_locked = application.to_csv_row(mock_user)
      assert_equal CSV.parse(header_with_locked).length, CSV.parse(row_with_locked).length,
        "Expected header and row to have the same number of columns, including Locked"
    end

    test 'to_cohort_csv' do
      application = build :pd_teacher1819_application
      optional_columns = {registered_workshop: false, accepted_teachercon: true}

      assert (header = Teacher1819Application.cohort_csv_header(optional_columns))
      assert (row = application.to_cohort_csv_row(optional_columns))
      assert_equal CSV.parse(header).length, CSV.parse(row).length,
        "Expected header and row to have the same number of columns"
    end

    test 'school cache' do
      school = create :school
      form_data_hash = build :pd_teacher1819_application_hash, school: school
      application = create :pd_teacher1819_application, form_data_hash: form_data_hash

      # Original query: School, SchoolDistrict
      assert_queries 2 do
        assert_equal school.name.titleize, application.school_name
        assert_equal school.school_district.name.titleize, application.district_name
      end

      # Cached
      assert_queries 0 do
        assert_equal school.name.titleize, application.school_name
        assert_equal school.school_district.name.titleize, application.district_name
      end
    end

    test 'cache prefetch' do
      school = create :school
      workshop = create :pd_workshop
      form_data_hash = build :pd_teacher1819_application_hash, school: school
      application = create :pd_teacher1819_application, form_data_hash: form_data_hash, pd_workshop_id: workshop.id

      # Workshop, Session, Enrollment, School, SchoolDistrict
      assert_queries 5 do
        Teacher1819Application.prefetch_associated_models([application])
      end

      assert_queries 0 do
        assert_equal school.name.titleize, application.school_name
        assert_equal school.school_district.name.titleize, application.district_name
        assert_equal workshop, application.workshop
      end
    end

    test 'memoized filtered_labels' do
      Teacher1819Application::FILTERED_LABELS.clear

      filtered_labels_csd = Teacher1819Application.filtered_labels('csd')
      assert filtered_labels_csd.include? :csd_which_grades
      refute filtered_labels_csd.include? :csp_which_grades
      assert_equal ['csd'], Teacher1819Application::FILTERED_LABELS.keys

      filtered_labels_csd = Teacher1819Application.filtered_labels('csp')
      refute filtered_labels_csd.include? :csd_which_grades
      assert filtered_labels_csd.include? :csp_which_grades
      assert_equal ['csd', 'csp'], Teacher1819Application::FILTERED_LABELS.keys
    end
  end
end
