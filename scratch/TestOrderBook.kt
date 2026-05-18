import java.util.TreeMap
import java.util.Collections
import java.util.concurrent.ConcurrentLinkedQueue

fun main() {
    val sells = TreeMap<Int, String>()
    sells[10] = "10 won sell"
    sells[99000] = "99000 won sell"
    sells[100000] = "100000 won sell"
    
    println("Sells order:")
    for ((k, v) in sells) {
        println(k)
    }

    val buys = TreeMap<Int, String>(Collections.reverseOrder())
    buys[10] = "10 won buy"
    buys[99000] = "99000 won buy"
    buys[100000] = "100000 won buy"

    println("Buys order:")
    for ((k, v) in buys) {
        println(k)
    }
}
