/// Module initialization
/// Sets up shared objects like the program registry
module suiguard::bounty_init {
    use suiguard::bounty_registry;

    /// One-time initialization function
    /// Creates the shared ProgramRegistry
    fun init(ctx: &mut sui::tx_context::TxContext) {
        bounty_registry::create_and_share(ctx);
    }

    #[test_only]
    /// Test-only init function
    public fun init_for_testing(ctx: &mut sui::tx_context::TxContext) {
        init(ctx)
    }
}
