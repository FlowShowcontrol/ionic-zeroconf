declare global  {
    interface PluginRegistry {
        ZeroConfPlugin?: ZeroConfPlugin;
    }
}
export interface ZeroConfPlugin {
    watch(options: {
        type: string;
        domain: string;
    }): Promise<any>;
    unwatch(options: {
        type: string;
        domain: string;
    }): Promise<any>;
}
