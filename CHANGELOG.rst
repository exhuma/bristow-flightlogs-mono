Changelog
=========

2026.09.14
----------

* **[breaking]** Move the image build here from the backend repo. This
  repo now owns the product's CalVer version and this changelog --
  previously the backend repo's -- since it is the only place that
  knows which pair of submodule commits shipped together. Both
  submodules keep their own quality-gate CI and stop publishing images
  or tagging their own releases.
* Retire the Ansible deployment automation (direct SSH access to the
  deployment host is gone). Deployment is a normal ``docker compose``
  install; see the backend manual's Maintenance Operations, Monitoring
  and Host Setup pages for what replaced the backup, anonymised-dump
  and monitoring playbooks.

2026.09.13
----------

* **[breaking]** Serve the web-application and the HTTP API from a
  single container. The API moved from the root of its own port to
  ``/api`` on the same hostname as the web-application, so
  ``https://host:8000/booking`` is now ``https://host/api/booking``.
  ``/docs`` moved to ``/api/docs`` and ``/manual`` to ``/api/manual``.
  See "Upgrading from the two-container deployment" in the manual for
  the operator steps.
* **[breaking]** Replace ``/healthz`` with three probes: ``/api/livez``
  (process liveness, consults nothing), ``/api/readyz`` (readiness,
  checks the database) and ``/api/healthz`` (overall health, including
  optional components). They answer ``503`` when failing, where the old
  endpoint always answered ``200`` and hid the failure in the body.
* **[breaking]** ``FLIGHTLOGS_CORS_ALLOWED_ORIGINS`` now defaults to
  empty, disabling cross-origin handling. The two halves are
  same-origin, so nothing needs it.
* Add ``FLIGHTLOGS_STATIC_ROOT``, naming the web-application bundle the
  image serves. Empty serves the API alone.
* Add ``FLIGHTLOGS_HTTP_REDIRECT_PORT``, a plain-HTTP listener that
  redirects to HTTPs, replacing what the separate web server did.
* Serve the security headers and cache-control policy that the separate
  web server used to add.

2026.08.03
----------

* Add ``POST /booking/bulk`` to create several bookings in one
  transaction, so a batch either persists in full or not at all.

2025.10.07
----------

* Fix issue with "most significant month" calculation


2025.08.26
----------

* Strip financial information from reports if permission is missing.

2025.07.20.1
------------

* Add missing deployment file

2025.07.20
----------

* **[breaking]** Wrap time-range values in the simulator report document.
* Add assignee distribution to simulator report.
* Increase comment fields to 10k characters.
* Fix detection of "admin-email" from environment variables.
* Fix error which prevented edits on kiosks.
* Revoke DR edit permissions from kiosk users.
* Update formulas in documentation (added missing formulas).


2025.07.10
----------

* Add new permission `view-defect-report:internal`


2025.06.04
----------

* Only emit "newly created" events on actual creation of object (not also on
  updates)

2025.06.01
----------

* Fix time-zone handling in weekly calendar export

2025.05.29
----------

* Fix e-mail notifications (Include missing files in distribution package)

2025.05.27
----------

* Handle time-zones on Excel export

2025.05.25
----------

* Defect Reports now *must* be related to a user
* Implement SMTP based user-notifications based on "watch" settings of users.

2025.03.22
----------

* Allow kiosks to store defect-reports

2025.03.16
----------

* Provide additional meta-data for defect-reports on request
* Provide option to export PDF export for one week only
* Disable overlap check with cancelled/no-show bookings

2025.02.15
----------

* Add support to upload files using "HTTP-BASIC".
* Fix defect-report filter when various filters have empty values.

2025.02.13
----------

* Fix defect-report filter when simulator ID is empty (backport from
  2025.02.15)

2025.01.31
----------

* Rework filename handling for attachments, hopefully fixing incorrect
  file-extensions.

2025.01.05
----------

* Fixed a bug that caused the simulator selection in defect-report KPIs to be
  ignored.

2025.01.03
----------

* **[major]** Add support for comments on defect reports
* **[major]** Add support for attachments on defect reports
* Add a new "public note" field on defect reports. This is visible for all
  users

2024.12.29
----------

* **[major]** Add support for "defect reports"
* Properly handle an error if data in the DB was corrupted
* Include "no-show" and "cancelled" in PDF export
* Include "reliability" calculation in simulator stats
* ``DELETE`` requests now report a ``204`` status
* Respond with an error when a user sends an unsupported query-filter
* Wrap LUA scripting errors in easier-to-understand user-errors
* Sort "OpenAPI" tags in the spec-file by name

2024.12.08
----------

* Increase precision of reported statistics

2024.11.11.112643
-----------------

* Add "optimistic locking" to prevent accidental overwrites in a multi-user
  environment

2024.11.02.163823
-----------------

* Fix issue with PDF export

2024.11.02.155813
-----------------

* Bugfixes which caused major regressions in the release

2024.11.02
----------

* Add option to download customer reports as Excel file
* Allow filtering bookings by instructor and course
* Round report values to 2 digits
* Provide LUA function to compare time-values
* Add more detail to integrity error messages

Reporting rework
~~~~~~~~~~~~~~~~

* Sessions that are not yet finished/running during the end of the report
  period are now excluded from it. Those that are running during the start of
  the report are included.
* Any booked time during maintenance slots is now considered as "available"
* **[changed]** Update reported stats as requested. This changes the data-model
  of report responses.

2024.10.14
----------

* Fix critical endless-loop bug in API implementation of PDF export

2024.10.13
----------

* Display Maintenance Window in PDF export
* Provide option to select time-zone for PDF export
* Provide option to anonymise all entries in the PDF export
* Fix timezone issues in PDF export

2024.10.11
----------

* Remove techlog overlap constraints
* Add support for PDF exports
* Provide new endpoint for simulator KPIs (/report/kpi). This endpoint may
  change or disappear in the future.
* Fix availability statistics on simulator reports
* Add "interrupts" to simulator reports
* Add "time-range" of the report to simulator reports


2024.09.29
----------

* Include additional context into server-logs to help debugging the expiring
  token-signature issue.

2024.09.22
----------

* **breaking:** Applying the "customer mask" on a customer query must now be
  passed using the ``reveal-customer-id`` key. Using ``customer`` will return
  only bookings from that selected customer.
* Add support for arbitrary OIDC identity providers (not only Microsoft)
* Add support to report an informative "banner" information for the API (f.ex.
  to state that it is in development/testing)
* Minor refactoring of the query to list techlogs
* Added an additional policy to the default/template techlog-policy


2024.09.15
----------

This is a bugfix release and does not bring any new features.

* Add data-validation for time-ranges. It now ensures for both the bookings and
  tech-logs that the "start" time is before the "end" time.
* Fix an error that prevented users from being deleted.
* Fix error that caused booking information to be visible for users without the
  appropriate permission.
* Fix error that prevented kiosks from displaying the customer-name.
* Fix error that prevented kiosks from re-prompting a new PIN code when they
  were invalidated in the "admin" section.
* Fix an error that prevented kiosks from being saved without "last-access"
  date.


2024.09.08.2
------------

* Fix error that prevented the creation of new kiosks

2024.09.08.1
------------

* Fix error raised when more than one kiosk machines are linked
* Fix error caused each time when updating Kiosks.
* Record "last-access" time of kiosks


2024.09.08
----------

* Fix regression caused by ``pyjwt`` causing Kiosk tokens to fail being decoded


2024.09.04
----------

* Switch JWT implementation from ``authlib`` to ``pyjwt``

2024.08.16
----------

* Provide endpoint to test policy-scripts, including display of ``script_log``
  calls.
* Provide filters to only return customers for a single simulator and
  time-range
* Improved error-display when an overlap occurs
* Provide server-side implementation for customer-reports (this was done on the
  front-end before this).
* Provide a route to find any resource by unique ID
* Improved the "Getting Help" page in the user-manual
* Fix techlog policy script.

2024.08.04
----------

* Allow to fetch all tech-logs (without filter) from the API
* Provide scripting engine to validate resources before saving them
* Provide additional user-roles for finer-grained access control

2024.06.20
----------

* Add new "customer-id" filter to booking queries. If specified all bookings of
  other customers will be masked as "busy"
* Update formula to calculate lost-time percentage
* Avoid errors for default "BU-Rate", "Numerical ID" and "TimeSlot" values

2024.05.27
----------

* Add a human-friendly numerical ID to tech-logs
* Fix an issue that ignored the "techlog-id" filter on bookings


2024.05.19
----------

* Add "cancellation date" to bookings
* Provide a "slim" response type for resources with images

2024.05.12
----------

* Add support for "corrective action"
* Renamed "instructor_notes" to "discrepancies"
* Store and report "no-shows"
* Ensure that "BU-Rate" is not leaked to users without permissions
* Apply gzip compression to responses larger than 1kB
* Booking labels are no longer mandatory
* Prevent complete query-crash on incomplete data
* [fix] "empty" tech-logs no longer cause the calendar view to crash

2024.04.27
----------

* Add support for Kiosk mode
* Move group to permission mapping from the database to the source-code
* Make it possible to update techlogs without updating the associated booking.
  This split is required for finer grained access control
* Add an "issuer" field for user-identities. This makes it possible to
  distinguish SSO users from other types of login

2024.03.20b1
------------

* Improve application and access logging
* Merge "frontend" and "backend" documentation
* Provide manual via the ``/manual`` route on the back-end
* Fixed "sign-off" and "instructor" handling in data-import
* Provide the ``SKIP_DB_INIT`` option to access the manual on
  empty/non-bootstrapped environments


2023.12.10b1
------------

* Move techlog related data from bookings into techlogs. This moves:

  - Crew details
  - Assigned Instructor
  - Signed Off By Instructor flag

* Include BU-Rate in Excel import for tech-logs
* Increase max-value for BU-Rates by one order of magnitude
* Improve import-error reporting
* Reword techlog imports for improved dealing with empty/bad input data
* Lost time is now correctly reported as positive value
* Provide filter to exclude unfinished tech-logs from sim-report card

2023.12.03a1
------------

* Increase auth-token timeout while investigating a token-refresh bug.

2023.12.01a1
------------

* Return HTTP 401 if the auth refresh token cannot be decoded
* Relation between booking & crew has changed to "one to many". This is more in
  line with the required use-cases.
* Prevent division by zero on simulator report response.
* Provide "anonymous" access to free/busy information.
* Consider an empty JWT token value as "not logged in" instead of returning an
  "internal server error".
* Add support for maintenance windows.
* Refuse overlapping time-slots on the server.
* Add possibility to import data from legacy Excel files.
* Improve OpenAPI documentation.
* Add optional SSL support directly in the container.
* Expose the "comments" field of bookings via the API.

2023.10.22a1
------------

* Added API endpoint for monthly simulator report

2023.10.21a1
------------

* Added API endpoints for user- and permission-management.
* Use a "persistent" SAML identifier for users.
* Implement database persistence.
* Add an error-handler for uncaught errors.
* Added API endpoints for customer management.
* Improve consistency in route names (renamed ``/roles`` to ``/role``)
* Add additional fields to tech-logs:
  * "safety-briefing-completed"
  * "technician sign-off"
  * "number of interrupts"
  * "instructor notes"



2023.09.04a1
------------

Added ``FLIGHTLOGS_VALIDATE_SSL_CERTS`` environment variable to disable
SSL checking.


2023.09.03a1
------------

Housekeeping release to move over to a new/private docker registry

2023.09.01a1
------------

This is an early release without any functionality other than authentication.
It serves as a point of exchange between the developer and the sys-admin team
to iron out any deployment and authentication issues.
