# Feature Specification: MQTT Broker Setup

**Feature Branch**: `600-broker-setup`

**Created**: 2026-06-23

**Status**: Active

**Input**: Consolidated from `specs/006-broker-setup/spec.md`: user entry, validation, secure persistence, editing, removal, and provisioning of MQTT broker configuration for Home Assistant control.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure broker connection details (Priority: P1)

The user can enter the host, port, username, and password for an existing MQTT broker. Once saved, Home Assistant control can retrieve a complete broker configuration through a provisioning interface.

**Why this priority**: Without broker details, the Home Assistant control path has no broker to connect to and remains inert.

**Independent Test**: Enter valid broker details and save; verify the provisioning interface returns host, port, username, password, and stable device ID, and verify username/password are stored in Keychain rather than UserDefaults.

**Acceptance Scenarios**:

1. **Given** no broker details are stored, **When** the user enters valid host, port, username, and password and saves, **Then** a complete broker configuration is available and remote control can use it.
2. **Given** the user enters invalid input, such as an empty host or a port outside 1 to 65535, **When** the user attempts to save, **Then** saving is rejected or prevented, a hint is shown, and no incomplete configuration is persisted.
3. **Given** broker details were saved, **When** persistence is inspected, **Then** password and username are in the Keychain and never in UserDefaults, logs, or committed files.
4. **Given** broker details were saved, **When** the app restarts, **Then** the details are still available.

---

### User Story 2 - Edit or remove broker details (Priority: P2)

The user can inspect existing broker details without seeing the saved password in plaintext, change them, or fully remove them. After removal, the app no longer has a broker configuration to provide.

**Why this priority**: Real setups need correction and disable paths, but they build on the initial save and provisioning flow.

**Independent Test**: Change saved details and verify the new configuration is returned; remove details and verify no configuration is returned and the Keychain secret is gone.

**Acceptance Scenarios**:

1. **Given** broker details are stored, **When** the user changes host, port, username, or password and saves, **Then** the available configuration reflects the new values and the old Keychain password is overwritten.
2. **Given** broker details are stored, **When** the user chooses remove, **Then** no broker configuration is available and the Keychain secret is deleted.
3. **Given** an existing password is stored, **When** the user opens the input form, **Then** the password is not prefilled or exposed in plaintext; the UI shows masking or an "is set" indicator instead.

### Edge Cases

- **Anonymous broker**: Although some brokers allow no credentials, this feature treats username and password as required; anonymous brokers are outside the MVP scope.
- **Default port**: If no port is entered, the TLS default port 8883 is suggested.
- **Whitespace or typos in host**: Input is trimmed; a host that is empty after trimming is invalid.
- **Partially saved data**: An incomplete configuration is never persisted; saving is atomic, either fully valid or not saved.
- **Device ID**: The stable device identifier needed by remote control is app-derived, not user-entered, and stable across app restarts.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-600-01**: The user MUST be able to enter broker host, port, username, and password.
- **FR-600-02**: Inputs MUST be validated before save: trimmed host non-empty, port from 1 to 65535, username non-empty, and password non-empty.
- **FR-600-03**: Invalid input MUST prevent saving and show a user-visible hint.
- **FR-600-04**: Username and password MUST be stored only in the Keychain and MUST NOT appear in UserDefaults, logs, cache, source code, or committed files.
- **FR-600-05**: Host and port MAY be stored as non-secret settings.
- **FR-600-06**: Saving MUST be atomic: the app MUST never persist a partial broker configuration.
- **FR-600-07**: The app MUST expose a complete broker configuration through a provisioning interface consumed by Home Assistant control, including host, port, username, password, and a derived stable device ID.
- **FR-600-08**: If any required broker detail is missing or invalid, the provisioning interface MUST report no configuration.
- **FR-600-09**: Stored broker details MUST persist across app restarts.
- **FR-600-10**: The user MUST be able to edit existing broker details, and saving a changed password MUST overwrite the Keychain password.
- **FR-600-11**: The user MUST be able to fully remove broker details; removal MUST clear both non-secret settings and Keychain secrets, and provisioning MUST then report no configuration.
- **FR-600-12**: When redisplaying existing broker details, the saved password MUST NOT be shown in plaintext; the UI MUST use masking, an empty field with an "is set" indicator, or equivalent.
- **FR-600-13**: The stable device ID MUST be app-derived, not user-entered, and stable across app restarts.

### Key Entities *(include if feature involves data)*

- **Broker Input**: The user-entered host, port, username, and password before validation.
- **Broker Configuration**: The complete validated connection configuration, including host, port, username, password, and derived device ID, as consumed by Home Assistant control.
- **Validation Result**: Whether broker input can be saved, plus the reason when it cannot.
- **Stable Device ID**: An app-derived identifier used by Home Assistant control for stable device/entity identity.

### Roadmap / Deferred (not yet built)

- Anonymous broker support remains out of scope for this milestone.
- Broker auto-discovery, multi-broker management, certificate pinning, and self-signed certificate handling remain out of scope.
- MQTT connection, discovery, and remote control behavior are handled by topic 700, not by broker setup.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-600-01**: After valid input and save, the provisioning interface returns a complete configuration with all fields and the stable device ID.
- **SC-600-02**: Empty host, out-of-range port, empty username, or empty password results in no persisted configuration and a visible validation hint.
- **SC-600-03**: Username and password appear only in the Keychain and not in UserDefaults, logs, cache, source code, or committed files.
- **SC-600-04**: After app restart, previously saved broker details remain available.
- **SC-600-05**: After removal, provisioning reports no configuration and the Keychain secret is deleted.
- **SC-600-06**: Changing the password overwrites the prior password, leaving no stale old secret.

## Assumptions

- The MQTT broker has a valid TLS certificate; this feature stores connection details and does not make TLS exceptions.
- The actual MQTT connection and Home Assistant discovery are implemented in topic 700.
- Anonymous brokers are out of scope, so username and password are required.
- The setup entry point appears in an existing calm settings or menu surface, preserving the default app experience.
