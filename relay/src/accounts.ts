export interface RelayAccount {
  id: string;
  label: string;
  refreshToken: string;
  subscriptionName: string;
}

export interface AccountStore {
  get(id: string): Promise<RelayAccount | null>;
  list(): Promise<RelayAccount[]>;
  save(account: RelayAccount): Promise<void>;
  remove(id: string): Promise<void>;
}

export interface WorkspaceEventsClient {
  deleteSubscription(subscriptionName: string): Promise<void>;
}

export interface OAuthClient {
  revokeRefreshToken(refreshToken: string): Promise<void>;
}

export interface TeardownDeps {
  store: AccountStore;
  workspaceEvents: WorkspaceEventsClient;
  oauth: OAuthClient;
}

export async function teardownAccount(
  deps: TeardownDeps,
  accountId: string,
  account: RelayAccount,
): Promise<void> {
  await deps.workspaceEvents.deleteSubscription(account.subscriptionName);
  await deps.oauth.revokeRefreshToken(account.refreshToken);
  await deps.store.remove(accountId);
}
