// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Initialization module for the triage voting system.
/// Creates and shares the TriageRegistry on module publish.
/// Also creates EmergencyAdminCap for emergency fast-tracking.
module suiguard::triage_init {
    use sui::tx_context::TxContext;
    use sui::transfer;

    use suiguard::triage_types;

    /// Module initializer - called once when the module is published
    /// Creates and shares the TriageRegistry
    /// Creates EmergencyAdminCap and transfers to deployer
    fun init(ctx: &mut TxContext) {
        // Create and share registry
        triage_types::create_and_share_registry(ctx);

        // Create emergency admin capability and transfer to deployer
        let admin_cap = triage_types::new_emergency_admin_cap(ctx);
        transfer::public_transfer(admin_cap, tx_context::sender(ctx));
    }

    /// Test-only initialization function
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
