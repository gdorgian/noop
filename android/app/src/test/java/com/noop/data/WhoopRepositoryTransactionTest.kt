package com.noop.data

import com.noop.protocol.RrSourceChannel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Proxy

class WhoopRepositoryTransactionTest {

    @Test
    fun mixedStreamBatchUsesOneTransactionForEveryDaoWrite() = runBlocking {
        var transactionCalls = 0
        var inTransaction = false
        val daoCalls = mutableListOf<String>()
        val dao = Proxy.newProxyInstance(
            WhoopDao::class.java.classLoader,
            arrayOf(WhoopDao::class.java),
        ) { _, method, _ ->
            assertTrue("${method.name} must run inside the batch transaction", inTransaction)
            daoCalls += method.name
            listOf(1L)
        } as WhoopDao
        val transactor = object : WhoopRepository.Transactor {
            override suspend fun <R> run(block: suspend () -> R): R {
                transactionCalls += 1
                assertFalse("transactions must not nest", inTransaction)
                inTransaction = true
                return try {
                    block()
                } finally {
                    inTransaction = false
                }
            }
        }

        val counts = WhoopRepository(dao, transactor).insert(
            streams = StreamBatch(
                hr = listOf(HrRow(ts = 100L, bpm = 60)),
                rr = listOf(RrRow(ts = 100L, rrMs = 1_000)),
                events = listOf(EventEntry(ts = 100L, kind = "test", payloadJSON = "{}")),
            ),
            deviceId = "my-whoop",
        )

        assertEquals(1, transactionCalls)
        assertEquals(listOf("insertHr", "insertRr", "insertEvents"), daoCalls)
        assertEquals(1, counts.hr)
        assertEquals(1, counts.rr)
        assertEquals(1, counts.events)
        assertFalse(inTransaction)
    }

    @Test
    fun emptyBatchSkipsTransactionAndDao() = runBlocking {
        var transactionCalls = 0
        val dao = Proxy.newProxyInstance(
            WhoopDao::class.java.classLoader,
            arrayOf(WhoopDao::class.java),
        ) { _, method, _ ->
            throw AssertionError("empty batch must not call ${method.name}")
        } as WhoopDao
        val transactor = object : WhoopRepository.Transactor {
            override suspend fun <R> run(block: suspend () -> R): R {
                transactionCalls += 1
                return block()
            }
        }

        assertEquals(InsertCounts(), WhoopRepository(dao, transactor).insert(StreamBatch(), "my-whoop"))
        assertEquals(0, transactionCalls)
    }

    @Test
    fun historicalExactKeyCollisionPromotesTaggedLiveRowInsideSameTransaction() = runBlocking {
        var transactionCalls = 0
        var inTransaction = false
        var insertedRows: List<RrInterval>? = null
        var promotionArgs: List<Any?>? = null
        val dao = Proxy.newProxyInstance(
            WhoopDao::class.java.classLoader,
            arrayOf(WhoopDao::class.java),
        ) { _, method, args ->
            assertTrue("${method.name} must run inside the batch transaction", inTransaction)
            when (method.name) {
                "insertRr" -> {
                    @Suppress("UNCHECKED_CAST")
                    val rows = args!![0] as List<RrInterval>
                    insertedRows = rows
                    listOf(-1L) // The tagged live copy already owns this exact primary key.
                }
                "promoteLiveRrCollisionToHistorical" -> {
                    promotionArgs = args!!.take(5)
                    1
                }
                else -> throw AssertionError("unexpected DAO call ${method.name}")
            }
        } as WhoopDao
        val transactor = object : WhoopRepository.Transactor {
            override suspend fun <R> run(block: suspend () -> R): R {
                transactionCalls += 1
                inTransaction = true
                return try {
                    block()
                } finally {
                    inTransaction = false
                }
            }
        }

        val counts = WhoopRepository(dao, transactor).insert(
            streams = StreamBatch(
                rr = listOf(RrRow(100L, 800, RrSourceChannel.WHOOP_HISTORICAL)),
            ),
            deviceId = "my-whoop",
        )

        assertEquals(1, transactionCalls)
        assertEquals(
            listOf(
                RrInterval(
                    deviceId = "my-whoop",
                    ts = 100L,
                    rrMs = 800,
                    seq = 0,
                    ord = 0,
                    srcChannel = RrSourceChannel.WHOOP_HISTORICAL.code,
                ),
            ),
            insertedRows,
        )
        assertEquals(listOf("my-whoop", 100L, 800, 0, 0), promotionArgs)
        assertEquals(0, counts.rr)
        assertEquals(1, counts.rrPromoted)
        assertFalse(inTransaction)
    }
}
