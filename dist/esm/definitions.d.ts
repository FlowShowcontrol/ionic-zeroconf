declare global  {
    interface PluginRegistry {
        ZeroConfPlugin?: ZeroConfPlugin;
    }
}
export interface ZeroConfPlugin {
    watch(options: {
        type: string;
        domain: string;
    }): Promise<{
        value: string;
    }>;
    unwatch(options: {
        type: string;
        domain: string;
    }): Promise<{
        value: string;
    }>;
}
