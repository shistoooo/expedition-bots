import { BotConfig } from './config';
export declare class ExpeditionBot {
    private client;
    private config;
    private token;
    private targetChannelId;
    private guild;
    constructor(config: BotConfig);
    private postInChannel;
    private executeMission;
    start(): Promise<void>;
}
