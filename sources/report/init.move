/// Bug Report Module Initialization
/// Sets up shared objects for duplicate detection
module suiguard::report_init {
    use suiguard::duplicate_registry;

    /// One-time initialization function
    /// Creates the shared DuplicateRegistry
    fun init(ctx: &mut sui::tx_context::TxContext) {
        duplicate_registry::create_and_share(ctx);
    }

    #[test_only]
    /// Test-only init function
    public fun init_for_testing(ctx: &mut sui::tx_context::TxContext) {
        init(ctx)
    }
}
