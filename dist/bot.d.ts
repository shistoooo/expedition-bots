import { BotConfig } from './config';
export declare class ExpeditionBot {
    private client;
    private config;
    private token;
    private targetChannelId;
    constructor(config: BotConfig);
    start(): Promise<void>;
}
