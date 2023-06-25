import { ModelInit, MutableModel, __modelMeta__, ManagedIdentifier } from "@aws-amplify/datastore";
// @ts-ignore
import { LazyLoading, LazyLoadingDisabled } from "@aws-amplify/datastore";

export enum TransactionType {
  EXPENSE = "EXPENSE",
  INCOME = "INCOME"
}



type EagerBudget = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Budget, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly total: number;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

type LazyBudget = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Budget, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly total: number;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

export declare type Budget = LazyLoading extends LazyLoadingDisabled ? EagerBudget : LazyBudget

export declare const Budget: (new (init: ModelInit<Budget>) => Budget) & {
  copyOf(source: Budget, mutator: (draft: MutableModel<Budget>) => MutableModel<Budget> | void): Budget;
}

type EagerTransaction = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Transaction, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly amount: number;
  readonly type: string;
  readonly category: string;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

type LazyTransaction = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Transaction, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly amount: number;
  readonly type: string;
  readonly category: string;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

export declare type Transaction = LazyLoading extends LazyLoadingDisabled ? EagerTransaction : LazyTransaction

export declare const Transaction: (new (init: ModelInit<Transaction>) => Transaction) & {
  copyOf(source: Transaction, mutator: (draft: MutableModel<Transaction>) => MutableModel<Transaction> | void): Transaction;
}