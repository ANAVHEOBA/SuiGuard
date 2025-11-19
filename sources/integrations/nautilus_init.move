/// Nautilus Module Initialization
/// Sets up shared objects for TEE attestation
module suiguard::nautilus_init {
    use suiguard::nautilus_registry;

    /// One-time initialization function
    /// Creates the shared EnclaveRegistry
    fun init(ctx: &mut sui::tx_context::TxContext) {
        nautilus_registry::create_and_share(ctx);
    }

    #[test_only]
    /// Test-only init function
    public fun init_for_testing(ctx: &mut sui::tx_context::TxContext) {
        init(ctx)
    }
}
